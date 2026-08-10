import { Router } from "express";
import type { ServerConfig } from "../config.js";
import {
  analyzeMealRequestSchema,
  listMealRecordsQuerySchema,
  normalizeImageBase64
} from "../domain/mealAnalysis.js";
import { isAuthenticatedRequest, requireAuth } from "../auth/authMiddleware.js";
import type { AuthUserLookup } from "../auth/authMiddleware.js";
import { prisma } from "../db/prisma.js";
import { ApiError, unauthorized } from "../errors.js";
import {
  OpenAIMealAnalysisService,
  type MealAnalysisService
} from "../services/openAIMealAnalysisService.js";
import { parseBody, parseQuery } from "./validation.js";
import { consumeAIUsageQuota } from "../services/aiUsageQuotaService.js";

export interface MealRecordRouterDependencies {
  analysisService?: MealAnalysisService | null;
  authUserLookup?: AuthUserLookup;
}

export function createMealRecordRouter(
  config: ServerConfig,
  dependencies: MealRecordRouterDependencies = {}
): Router {
  const router = Router();
  const configuredAnalysisService = config.openAIAPIKey
    ? new OpenAIMealAnalysisService({
      apiKey: config.openAIAPIKey,
      model: config.openAIMealAnalysisModel,
      proxyURL: config.openAIProxyURL
    })
    : null;
  const analysisService = dependencies.analysisService === undefined
    ? configuredAnalysisService
    : dependencies.analysisService;

  router.use(requireAuth(config, dependencies.authUserLookup));

  router.get("/", async (request, response, next) => {
    try {
      if (!isAuthenticatedRequest(request)) {
        throw unauthorized();
      }

      const query = parseQuery(listMealRecordsQuerySchema, request.query);
      const records = await prisma.mealRecord.findMany({
        where: {
          userId: request.auth.userId,
          mealDate: query.date
        },
        orderBy: { recordedAt: "asc" }
      });

      response.json({ records: records.map(serializeMealRecord) });
    } catch (error) {
      next(error);
    }
  });

  router.post("/analyze", async (request, response, next) => {
    try {
      if (!isAuthenticatedRequest(request)) {
        throw unauthorized();
      }

      const input = parseBody(analyzeMealRequestSchema, request.body);
      if (!analysisService) {
        throw new ApiError(503, "MEAL_ANALYSIS_UNAVAILABLE", "餐食分析服务暂时不可用，请稍后重试。");
      }

      const [profile, recentReadings] = await Promise.all([
        prisma.userProfile.findUnique({ where: { userId: request.auth.userId } }),
        prisma.bloodPressureReading.findMany({
          where: { userId: request.auth.userId, deletedAt: null },
          orderBy: { measuredAt: "desc" },
          take: 10
        })
      ]);

      await consumeAIUsageQuota({
        userId: request.auth.userId,
        feature: "meal_analysis",
        dailyLimit: config.mealAnalysisDailyLimit
      });

      let result;
      try {
        result = await analysisService.analyze(normalizeImageBase64(input.imageBase64), {
          mealType: input.mealType,
          recordedAt: input.recordedAt,
          timeZone: input.timeZone,
          profile: {
            age: profile ? new Date().getUTCFullYear() - profile.birthYear : null,
            sex: profile?.sex ?? null,
            heightCm: decimalToNumber(profile?.heightCm),
            weightKg: decimalToNumber(profile?.weightKg),
            todaySteps: profile?.dailySteps ?? null,
            exerciseMinutes: profile?.exerciseMinutes ?? null,
            restingHeartRate: profile?.restingHeartRate ?? null,
            sleepHours: decimalToNumber(profile?.sleepHours)
          },
          recentBloodPressureReadings: recentReadings.map((reading) => ({
            systolic: reading.systolic,
            diastolic: reading.diastolic,
            pulse: reading.pulse,
            measuredAt: reading.measuredAt.toISOString()
          }))
        });
      } catch (error) {
        console.warn("OpenAI meal analysis failed.", error);
        throw new ApiError(502, "MEAL_ANALYSIS_FAILED", "暂时无法分析这张照片，请稍后重试。");
      }

      if (!result.canAnalyze) {
        throw new ApiError(422, "MEAL_IMAGE_UNCLEAR", result.recognition);
      }

      const analysis = formatAnalysis(result);
      const similarSuggestion = formatSuggestion(result);

      // The image is deliberately never included in this database write.
      const record = await prisma.mealRecord.upsert({
        where: {
          userId_mealDate_mealType: {
            userId: request.auth.userId,
            mealDate: input.mealDate,
            mealType: input.mealType
          }
        },
        create: {
          userId: request.auth.userId,
          mealType: input.mealType,
          mealDate: input.mealDate,
          analysis,
          similarSuggestion,
          recognition: result.recognition,
          dietaryStructureAnalysis: result.dietaryStructureAnalysis,
          cookingMethodAnalysis: result.cookingMethodAnalysis,
          dietaryStructureSuggestion: result.dietaryStructureSuggestion,
          cookingMethodSuggestion: result.cookingMethodSuggestion,
          cardSummary: result.cardSummary,
          recordedAt: new Date(input.recordedAt)
        },
        update: {
          analysis,
          similarSuggestion,
          recognition: result.recognition,
          dietaryStructureAnalysis: result.dietaryStructureAnalysis,
          cookingMethodAnalysis: result.cookingMethodAnalysis,
          dietaryStructureSuggestion: result.dietaryStructureSuggestion,
          cookingMethodSuggestion: result.cookingMethodSuggestion,
          cardSummary: result.cardSummary,
          recordedAt: new Date(input.recordedAt)
        }
      });

      response.json({ record: serializeMealRecord(record), source: "openai" });
    } catch (error) {
      next(error);
    }
  });

  return router;
}

function serializeMealRecord(record: {
  id: string;
  mealType: string;
  mealDate: string;
  analysis: string;
  similarSuggestion: string;
  recognition: string | null;
  dietaryStructureAnalysis: string | null;
  cookingMethodAnalysis: string | null;
  dietaryStructureSuggestion: string | null;
  cookingMethodSuggestion: string | null;
  cardSummary: string;
  recordedAt: Date;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: record.id,
    mealType: record.mealType,
    mealDate: record.mealDate,
    analysis: record.analysis,
    similarSuggestion: record.similarSuggestion,
    recognition: record.recognition,
    dietaryStructureAnalysis: record.dietaryStructureAnalysis,
    cookingMethodAnalysis: record.cookingMethodAnalysis,
    dietaryStructureSuggestion: record.dietaryStructureSuggestion,
    cookingMethodSuggestion: record.cookingMethodSuggestion,
    cardSummary: record.cardSummary,
    recordedAt: record.recordedAt.toISOString(),
    createdAt: record.createdAt.toISOString(),
    updatedAt: record.updatedAt.toISOString()
  };
}

function formatAnalysis(result: {
  recognition: string;
  dietaryStructureAnalysis: string;
  cookingMethodAnalysis: string;
}): string {
  return [
    `识别：${result.recognition}`,
    `饮食结构：${result.dietaryStructureAnalysis}`,
    `烹饪方式：${result.cookingMethodAnalysis}`
  ].join("\n");
}

function formatSuggestion(result: {
  dietaryStructureSuggestion: string;
  cookingMethodSuggestion: string;
}): string {
  return [
    `饮食结构：${result.dietaryStructureSuggestion}`,
    `烹饪方式：${result.cookingMethodSuggestion}`
  ].join("\n");
}

function decimalToNumber(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "number") {
    return value;
  }
  if (typeof value === "object" && "toNumber" in value && typeof value.toNumber === "function") {
    return value.toNumber();
  }
  return Number(value);
}
