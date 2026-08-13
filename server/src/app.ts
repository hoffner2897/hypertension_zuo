import express, { type ErrorRequestHandler, type RequestHandler } from "express";
import { BadRequestError, parseRecognizeBPRequest } from "./domain/bloodPressureRecognition.js";
import type { ServerConfig } from "./config.js";
import { createAuthRouter } from "./routes/authRoutes.js";
import { createProfileRouter } from "./routes/profileRoutes.js";
import { createReadingRouter, createReadingSyncRouter } from "./routes/readingRoutes.js";
import { createActionAdjustmentRouter } from "./routes/actionAdjustmentRoutes.js";
import { MockBPRecognitionService, type BPRecognitionService } from "./services/bpRecognitionService.js";
import { OpenAIBPRecognitionService } from "./services/openAIBPRecognitionService.js";
import { createMealRecordRouter } from "./routes/mealRecordRoutes.js";
import type { MealAnalysisService } from "./services/openAIMealAnalysisService.js";
import type { AuthUserLookup } from "./auth/authMiddleware.js";
import { isAuthenticatedRequest, requireAuth } from "./auth/authMiddleware.js";
import { unauthorized } from "./errors.js";
import { consumeAIUsageQuota } from "./services/aiUsageQuotaService.js";
import {
  createExerciseActionRouter,
  type ExerciseActionRepository
} from "./routes/exerciseActionRoutes.js";
import {
  createResearchActionRouter,
  type ResearchActionRepository
} from "./routes/researchActionRoutes.js";

export interface AppDependencies {
  mealAnalysisService?: MealAnalysisService | null;
  authUserLookup?: AuthUserLookup;
  recognitionService?: BPRecognitionService;
  exerciseActionRepository?: ExerciseActionRepository;
  researchActionRepository?: ResearchActionRepository;
}

export function createApp(config: ServerConfig, dependencies: AppDependencies = {}): express.Express {
  const app = express();
  const recognitionService = dependencies.recognitionService ?? makeRecognitionService(config);

  app.use(corsHeaders);
  app.use(optionsHandler);
  app.use(express.json({ limit: "8mb" }));
  app.use("/auth", createAuthRouter(config, dependencies.authUserLookup));
  app.use("/profile", createProfileRouter(config, dependencies.authUserLookup));
  app.use("/readings", createReadingRouter(config, dependencies.authUserLookup));
  app.use("/sync/readings", createReadingSyncRouter(config, dependencies.authUserLookup));
  app.use("/action-adjustments", createActionAdjustmentRouter(config, dependencies.authUserLookup));
  app.use("/meal-records", createMealRecordRouter(config, {
    analysisService: dependencies.mealAnalysisService,
    authUserLookup: dependencies.authUserLookup
  }));
  app.use("/exercise-actions", createExerciseActionRouter(config, {
    authUserLookup: dependencies.authUserLookup,
    repository: dependencies.exerciseActionRepository
  }));
  app.use("/research-actions", createResearchActionRouter(config, {
    authUserLookup: dependencies.authUserLookup,
    repository: dependencies.researchActionRepository
  }));

  app.get("/health", (_request, response) => {
    response.json({
      ok: true,
      service: "bphealth-server",
      recognitionMode: config.recognitionMode,
      researchActionHistory: true
    });
  });

  app.post("/recognize-bp", requireAuth(config, dependencies.authUserLookup), async (request, response, next) => {
    try {
      if (!isAuthenticatedRequest(request)) {
        throw unauthorized();
      }

      const { image } = parseRecognizeBPRequest(request.body);
      if (config.recognitionMode === "openai") {
        await consumeAIUsageQuota({
          userId: request.auth.userId,
          feature: "bp_recognition",
          dailyLimit: config.bpRecognitionDailyLimit
        });
      }
      const result = await recognitionService.recognize(image);
      response.json(result);
    } catch (error) {
      next(error);
    }
  });

  app.use((_request, response) => {
    response.status(404).json({
      code: "NOT_FOUND"
    });
  });

  app.use(errorHandler);

  return app;
}

function makeRecognitionService(config: ServerConfig): BPRecognitionService {
  if (config.recognitionMode === "mock") {
    return new MockBPRecognitionService();
  }

  if (!config.openAIAPIKey) {
    throw new Error("OPENAI_API_KEY is required when BP_RECOGNITION_MODE=openai.");
  }

  return new OpenAIBPRecognitionService({
    apiKey: config.openAIAPIKey,
    model: config.openAIModel,
    proxyURL: config.openAIProxyURL
  });
}

const corsHeaders: RequestHandler = (_request, response, next) => {
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS");
  response.setHeader("Access-Control-Allow-Headers", "Authorization,Content-Type");
  next();
};

const optionsHandler: RequestHandler = (request, response, next) => {
  if (request.method === "OPTIONS") {
    response.sendStatus(204);
    return;
  }

  next();
};

const errorHandler: ErrorRequestHandler = (error, _request, response, _next) => {
  const statusCode = statusCodeForError(error);
  response.status(statusCode).json({
    code: codeForError(error),
    message: messageForError(error)
  });
};

function statusCodeForError(error: unknown): number {
  if (error instanceof BadRequestError) {
    return error.statusCode;
  }

  if (isErrorWithStatusCode(error)) {
    return error.statusCode;
  }

  if (error instanceof SyntaxError) {
    return 400;
  }

  return 500;
}

function codeForError(error: unknown): string {
  if (isPayloadTooLargeError(error)) {
    return "PAYLOAD_TOO_LARGE";
  }

  if (error instanceof BadRequestError || error instanceof SyntaxError) {
    return "BAD_REQUEST";
  }

  if (isErrorWithCode(error)) {
    return error.code;
  }

  return "INTERNAL_SERVER_ERROR";
}

function messageForError(error: unknown): string {
  if (isPayloadTooLargeError(error)) {
    return "Request body is too large.";
  }

  if (error instanceof SyntaxError) {
    return "Malformed JSON request body.";
  }

  if (error instanceof BadRequestError || isErrorWithCode(error)) {
    return error.message;
  }

  return "Unexpected server error.";
}

function isErrorWithStatusCode(error: unknown): error is Error & { statusCode: number } {
  return error instanceof Error && "statusCode" in error && typeof error.statusCode === "number";
}

function isErrorWithCode(error: unknown): error is Error & { code: string } {
  return error instanceof Error && "code" in error && typeof error.code === "string";
}

function isPayloadTooLargeError(error: unknown): boolean {
  return error instanceof Error
    && (("statusCode" in error && error.statusCode === 413)
      || ("type" in error && error.type === "entity.too.large"));
}
