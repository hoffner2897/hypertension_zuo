import { Router } from "express";
import type { ServerConfig } from "../config.js";
import {
  actionSuggestionDisclaimer,
  actionTrendSuggestionRequestSchema,
  actionTrendSuggestionResponseSchema,
  buildTrustedActionSuggestionPlan,
  makeActionSuggestionDataNote,
  makeRuleBasedSuggestions,
  resolveOpenAISelections
} from "../domain/actionTrendSuggestions.js";
import { requireAuth } from "../auth/authMiddleware.js";
import { OpenAIActionTrendSuggestionService } from "../services/openAIActionTrendSuggestionService.js";
import { parseBody } from "./validation.js";

export function createActionAdjustmentRouter(config: ServerConfig): Router {
  const router = Router();
  const openAIService = config.openAIAPIKey
    ? new OpenAIActionTrendSuggestionService({
      apiKey: config.openAIAPIKey,
      model: config.openAIActionSuggestionModel,
      proxyURL: config.openAIProxyURL
    })
    : null;

  router.use(requireAuth(config));

  router.post("/trend-suggestions", async (request, response, next) => {
    try {
      const input = parseBody(actionTrendSuggestionRequestSchema, request.body);
      const plan = buildTrustedActionSuggestionPlan(input);
      let suggestions = makeRuleBasedSuggestions(plan.candidates);
      let source: "openai" | "rule_based" = "rule_based";

      if (openAIService && plan.candidates.length > 0) {
        try {
          const selections = await openAIService.selectAndPolish(plan.candidates);
          suggestions = resolveOpenAISelections(selections, plan.candidates);
          source = "openai";
        } catch (error) {
          console.warn("OpenAI action trend suggestion failed; returning rule-based suggestions.", error);
        }
      }

      const payload = actionTrendSuggestionResponseSchema.parse({
        status: suggestions.length > 0 ? "ready" : "no_suggestions",
        source,
        evidenceDays: plan.evidenceDays,
        suggestions,
        dataNote: makeActionSuggestionDataNote(plan.evidenceDays),
        disclaimer: actionSuggestionDisclaimer
      });

      response.json(payload);
    } catch (error) {
      next(error);
    }
  });

  return router;
}
