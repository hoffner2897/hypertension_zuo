import { Router } from "express";
import type { ServerConfig } from "../config.js";
import {
  actionSuggestionDisclaimer,
  actionTrendSuggestionRequestSchema,
  buildTrustedActionSuggestionPlan,
  makeActionSuggestionDataNote,
  makeRuleBasedSuggestions,
} from "../domain/actionTrendSuggestions.js";
import { isAuthenticatedRequest, requireAuth } from "../auth/authMiddleware.js";
import type { AuthUserLookup } from "../auth/authMiddleware.js";
import { buildActionAdviceEvidence, makeRuleBasedActionAdvice } from "../domain/actionAdvice.js";
import { OpenAIActionAdviceService } from "../services/openAIActionAdviceService.js";
import { prisma } from "../db/prisma.js";
import { unauthorized } from "../errors.js";
import { parseBody } from "./validation.js";

export function createActionAdjustmentRouter(config: ServerConfig, authUserLookup?: AuthUserLookup): Router {
  const router = Router();
  const openAIService = config.openAIAPIKey
    ? new OpenAIActionAdviceService({
      apiKey: config.openAIAPIKey,
      model: config.openAIActionSuggestionModel,
      proxyURL: config.openAIProxyURL
    })
    : null;

  router.use(requireAuth(config, authUserLookup));

  router.post("/trend-suggestions", async (request, response, next) => {
    try {
      const input = parseBody(actionTrendSuggestionRequestSchema, request.body);
      if (!isAuthenticatedRequest(request)) throw unauthorized();
      const since = new Date(Date.parse(input.now) - 14 * 24 * 60 * 60 * 1000);
      let meals: Awaited<ReturnType<typeof prisma.mealRecord.findMany>> = [];
      let exercises: Awaited<ReturnType<typeof prisma.exerciseAction.findMany>> = [];
      try {
        [meals, exercises] = await Promise.all([
          prisma.mealRecord.findMany({
            where: { userId: request.auth.userId, recordedAt: { gte: since } },
            orderBy: { recordedAt: "desc" }, take: 42
          }),
          prisma.exerciseAction.findMany({
            where: { userId: request.auth.userId, deletedAt: null, scheduledStartAt: { gte: since } },
            orderBy: { scheduledStartAt: "desc" }, take: 200
          })
        ]);
      } catch (error) {
        console.warn("Action advice database context unavailable; using client-synced action evidence.", error);
      }
      const plan = buildTrustedActionSuggestionPlan(input);
      const suggestions = makeRuleBasedSuggestions(plan.candidates);
      const evidence = buildActionAdviceEvidence(
        input.timeZone,
        meals.map((meal) => ({
          mealType: meal.mealType, mealDate: meal.mealDate, recognition: meal.recognition,
          dietaryStructureAnalysis: meal.dietaryStructureAnalysis, cookingMethodAnalysis: meal.cookingMethodAnalysis,
          dietaryStructureSuggestion: meal.dietaryStructureSuggestion, cookingMethodSuggestion: meal.cookingMethodSuggestion
        })),
        [
          ...exercises.map((exercise) => ({
            id: exercise.id,
            title: exercise.title, localDay: exercise.localDay, scheduledStartAt: exercise.scheduledStartAt.toISOString(),
            durationMinutes: exercise.durationMinutes,
            actualDurationMinutes: exercise.actualDurationSeconds == null ? null : Math.round(exercise.actualDurationSeconds / 60),
            status: exercise.status
          })),
          ...[...input.recentActions, ...input.todayActions]
            .filter((exercise) => exercise.type === "exercise")
            .map((exercise) => ({
              id: exercise.id,
              title: exercise.title,
              localDay: formatLocalDay(exercise.scheduledStartAt, input.timeZone),
              scheduledStartAt: exercise.scheduledStartAt,
              durationMinutes: exercise.durationMinutes ?? 0,
              actualDurationMinutes: null,
              status: exercise.status
            }))
        ]
      );
      let advice = makeRuleBasedActionAdvice(evidence);
      let source: "openai" | "rule_based" = "rule_based";

      if (openAIService && (evidence.meals.length > 0 || evidence.exercises.length > 0)) {
        try {
          advice = await openAIService.generate(evidence, advice);
          source = "openai";
        } catch (error) {
          console.warn("OpenAI action advice failed; returning rule-based advice.", error);
        }
      }

      const payload = {
        status: evidence.meals.length > 0 || evidence.exercises.length > 0 ? "ready" : "no_suggestions",
        source,
        evidenceDays: Math.max(plan.evidenceDays, new Set([...evidence.meals.map((item) => item.mealDate), ...evidence.exercises.map((item) => item.localDay)]).size),
        suggestions,
        advice,
        dataNote: makeActionSuggestionDataNote(plan.evidenceDays),
        disclaimer: actionSuggestionDisclaimer
      };

      response.json(payload);
    } catch (error) {
      next(error);
    }
  });

  return router;
}

function formatLocalDay(value: string, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date(value));
  const part = (type: string) => parts.find((item) => item.type === type)?.value ?? "00";
  return `${part("year")}-${part("month")}-${part("day")}`;
}
