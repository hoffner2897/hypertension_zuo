import { Prisma } from "@prisma/client";
import { prisma } from "../db/prisma.js";
import { tooManyRequests } from "../errors.js";

export type AIUsageFeature = "bp_recognition" | "meal_analysis";

export interface ConsumeAIUsageQuotaInput {
  userId: string;
  feature: AIUsageFeature;
  dailyLimit: number;
  now?: Date;
}

export async function consumeAIUsageQuota(input: ConsumeAIUsageQuotaInput): Promise<number> {
  if (!Number.isInteger(input.dailyLimit) || input.dailyLimit < 1) {
    throw new Error("AI daily quota must be a positive integer.");
  }

  const usageDate = utcStartOfDay(input.now ?? new Date());
  const rows = await prisma.$queryRaw<Array<{ requestCount: number }>>(Prisma.sql`
    INSERT INTO "ai_daily_usage" (
      "user_id",
      "usage_date",
      "feature",
      "request_count",
      "created_at",
      "updated_at"
    ) VALUES (
      ${input.userId}::uuid,
      ${usageDate},
      CAST(${input.feature} AS "AIUsageFeature"),
      1,
      CURRENT_TIMESTAMP,
      CURRENT_TIMESTAMP
    )
    ON CONFLICT ("user_id", "usage_date", "feature")
    DO UPDATE SET
      "request_count" = "ai_daily_usage"."request_count" + 1,
      "updated_at" = CURRENT_TIMESTAMP
    WHERE "ai_daily_usage"."request_count" < ${input.dailyLimit}
    RETURNING "request_count" AS "requestCount"
  `);

  const requestCount = rows[0]?.requestCount;
  if (requestCount === undefined) {
    throw tooManyRequests(
      "AI_DAILY_QUOTA_EXCEEDED",
      "今日 AI 功能使用次数已达上限，请明天再试。"
    );
  }

  return requestCount;
}

function utcStartOfDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}
