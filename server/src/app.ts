import express, { type ErrorRequestHandler, type RequestHandler } from "express";
import { BadRequestError, parseRecognizeBPRequest } from "./domain/bloodPressureRecognition.js";
import type { ServerConfig } from "./config.js";
import { createAuthRouter } from "./routes/authRoutes.js";
import { createProfileRouter } from "./routes/profileRoutes.js";
import { createReadingRouter, createReadingSyncRouter } from "./routes/readingRoutes.js";
import { MockBPRecognitionService, type BPRecognitionService } from "./services/bpRecognitionService.js";
import { OpenAIBPRecognitionService } from "./services/openAIBPRecognitionService.js";

export function createApp(config: ServerConfig): express.Express {
  const app = express();
  const recognitionService = makeRecognitionService(config);

  app.use(corsHeaders);
  app.use(optionsHandler);
  app.use(express.json({ limit: "8mb" }));
  app.use("/auth", createAuthRouter(config));
  app.use("/profile", createProfileRouter(config));
  app.use("/readings", createReadingRouter(config));
  app.use("/sync/readings", createReadingSyncRouter(config));

  app.get("/health", (_request, response) => {
    response.json({
      ok: true,
      service: "bphealth-server",
      recognitionMode: config.recognitionMode
    });
  });

  app.post("/recognize-bp", async (request, response, next) => {
    try {
      const { imageBase64 } = parseRecognizeBPRequest(request.body);
      const result = await recognitionService.recognize(imageBase64);
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
  if (error instanceof BadRequestError || error instanceof SyntaxError) {
    return "BAD_REQUEST";
  }

  if (isErrorWithCode(error)) {
    return error.code;
  }

  return "INTERNAL_SERVER_ERROR";
}

function messageForError(error: unknown): string {
  if (error instanceof Error) {
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
