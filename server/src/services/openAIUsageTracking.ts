import { Prisma } from "@prisma/client";
import { prisma } from "../db/prisma.js";

export type TrackedAIFeature =
  | "bp_recognition"
  | "meal_analysis"
  | "bp_interpretation"
  | "action_advice";

export interface OpenAIUsageContext {
  userId: string;
  feature: TrackedAIFeature;
}

export interface OpenAIResponseUsage {
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
}

interface ResponsesUsagePayload {
  input_tokens?: unknown;
  output_tokens?: unknown;
  input_tokens_details?: { cached_tokens?: unknown };
  output_tokens_details?: { reasoning_tokens?: unknown };
}

interface UsageRecordInput {
  context: OpenAIUsageContext;
  model: string;
  succeeded: boolean;
  usage?: OpenAIResponseUsage;
  errorCode?: string;
}

export function parseOpenAIResponseUsage(payload: ResponsesUsagePayload | undefined): OpenAIResponseUsage {
  return {
    inputTokens: nonNegativeInteger(payload?.input_tokens),
    cachedInputTokens: nonNegativeInteger(payload?.input_tokens_details?.cached_tokens),
    outputTokens: nonNegativeInteger(payload?.output_tokens),
    reasoningTokens: nonNegativeInteger(payload?.output_tokens_details?.reasoning_tokens)
  };
}

export async function recordOpenAIUsage(input: UsageRecordInput): Promise<void> {
  const usage = input.usage ?? emptyUsage;
  const usageDate = utcStartOfDay(new Date());
  const estimatedCostMicrousd = estimateCostMicrousd(input.model, usage);
  const errorCode = input.errorCode?.slice(0, 80) ?? null;

  try {
    await prisma.$executeRaw(Prisma.sql`
      INSERT INTO "ai_cost_daily_usage" (
        "user_id", "usage_date", "feature", "model",
        "request_count", "success_count", "failure_count", "cache_hit_count",
        "input_tokens", "cached_input_tokens", "output_tokens", "reasoning_tokens",
        "estimated_cost_microusd", "last_error_code", "created_at", "updated_at"
      ) VALUES (
        ${input.context.userId}::uuid, ${usageDate}, CAST(${input.context.feature} AS "AIUsageFeature"), ${input.model},
        1, ${input.succeeded ? 1 : 0}, ${input.succeeded ? 0 : 1}, 0,
        ${usage.inputTokens}, ${usage.cachedInputTokens}, ${usage.outputTokens}, ${usage.reasoningTokens},
        ${estimatedCostMicrousd}, ${errorCode}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
      ON CONFLICT ("user_id", "usage_date", "feature", "model")
      DO UPDATE SET
        "request_count" = "ai_cost_daily_usage"."request_count" + 1,
        "success_count" = "ai_cost_daily_usage"."success_count" + ${input.succeeded ? 1 : 0},
        "failure_count" = "ai_cost_daily_usage"."failure_count" + ${input.succeeded ? 0 : 1},
        "input_tokens" = "ai_cost_daily_usage"."input_tokens" + ${usage.inputTokens},
        "cached_input_tokens" = "ai_cost_daily_usage"."cached_input_tokens" + ${usage.cachedInputTokens},
        "output_tokens" = "ai_cost_daily_usage"."output_tokens" + ${usage.outputTokens},
        "reasoning_tokens" = "ai_cost_daily_usage"."reasoning_tokens" + ${usage.reasoningTokens},
        "estimated_cost_microusd" = "ai_cost_daily_usage"."estimated_cost_microusd" + ${estimatedCostMicrousd},
        "last_error_code" = ${errorCode},
        "updated_at" = CURRENT_TIMESTAMP
    `);
  } catch (error) {
    console.warn("AI cost usage tracking unavailable.", error);
  }
}

export async function recordOpenAICacheHit(context: OpenAIUsageContext, model: string): Promise<void> {
  const usageDate = utcStartOfDay(new Date());
  try {
    await prisma.$executeRaw(Prisma.sql`
      INSERT INTO "ai_cost_daily_usage" (
        "user_id", "usage_date", "feature", "model",
        "request_count", "success_count", "failure_count", "cache_hit_count",
        "input_tokens", "cached_input_tokens", "output_tokens", "reasoning_tokens",
        "estimated_cost_microusd", "created_at", "updated_at"
      ) VALUES (
        ${context.userId}::uuid, ${usageDate}, CAST(${context.feature} AS "AIUsageFeature"), ${model},
        0, 0, 0, 1, 0, 0, 0, 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      )
      ON CONFLICT ("user_id", "usage_date", "feature", "model")
      DO UPDATE SET
        "cache_hit_count" = "ai_cost_daily_usage"."cache_hit_count" + 1,
        "updated_at" = CURRENT_TIMESTAMP
    `);
  } catch (error) {
    console.warn("AI cache usage tracking unavailable.", error);
  }
}

export function openAIErrorCode(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  if (message.includes("credit_balance_exhausted")) return "credit_balance_exhausted";
  if (message.includes("insufficient_quota")) return "insufficient_quota";
  const status = message.match(/\b([45]\d{2})\b/)?.[1];
  return status ? `openai_${status}` : "openai_request_failed";
}

function estimateCostMicrousd(model: string, usage: OpenAIResponseUsage): number {
  const pricing = pricingForModel(model);
  if (!pricing) return 0;
  const cached = Math.min(usage.cachedInputTokens, usage.inputTokens);
  const uncached = usage.inputTokens - cached;
  return Math.round(
    uncached * pricing.inputPerMillion
      + cached * pricing.cachedInputPerMillion
      + usage.outputTokens * pricing.outputPerMillion
  );
}

function pricingForModel(model: string): {
  inputPerMillion: number;
  cachedInputPerMillion: number;
  outputPerMillion: number;
} | null {
  if (model.startsWith("gpt-5.6-terra")) {
    return { inputPerMillion: 2, cachedInputPerMillion: 0.2, outputPerMillion: 12 };
  }
  if (model.startsWith("gpt-5.6-luna")) {
    return { inputPerMillion: 0.2, cachedInputPerMillion: 0.02, outputPerMillion: 1.2 };
  }
  if (model.startsWith("gpt-5.5") || model.startsWith("gpt-5.6-sol") || model === "gpt-5.6") {
    return { inputPerMillion: 5, cachedInputPerMillion: 0.5, outputPerMillion: 30 };
  }
  return null;
}

function nonNegativeInteger(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
}

function utcStartOfDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

const emptyUsage: OpenAIResponseUsage = {
  inputTokens: 0,
  cachedInputTokens: 0,
  outputTokens: 0,
  reasoningTokens: 0
};
