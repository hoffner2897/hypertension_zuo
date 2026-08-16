ALTER TYPE "AIUsageFeature" ADD VALUE IF NOT EXISTS 'bp_interpretation';
ALTER TYPE "AIUsageFeature" ADD VALUE IF NOT EXISTS 'action_advice';

CREATE TABLE "ai_cost_daily_usage" (
    "user_id" UUID NOT NULL,
    "usage_date" DATE NOT NULL,
    "feature" "AIUsageFeature" NOT NULL,
    "model" VARCHAR(80) NOT NULL,
    "request_count" INTEGER NOT NULL DEFAULT 0,
    "success_count" INTEGER NOT NULL DEFAULT 0,
    "failure_count" INTEGER NOT NULL DEFAULT 0,
    "cache_hit_count" INTEGER NOT NULL DEFAULT 0,
    "input_tokens" BIGINT NOT NULL DEFAULT 0,
    "cached_input_tokens" BIGINT NOT NULL DEFAULT 0,
    "output_tokens" BIGINT NOT NULL DEFAULT 0,
    "reasoning_tokens" BIGINT NOT NULL DEFAULT 0,
    "estimated_cost_microusd" BIGINT NOT NULL DEFAULT 0,
    "last_error_code" VARCHAR(80),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_cost_daily_usage_pkey" PRIMARY KEY ("user_id", "usage_date", "feature", "model")
);

CREATE TABLE "action_advice_cache" (
    "user_id" UUID NOT NULL,
    "evidence_fingerprint" VARCHAR(64) NOT NULL,
    "model" VARCHAR(80) NOT NULL,
    "advice" JSONB NOT NULL,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "action_advice_cache_pkey" PRIMARY KEY ("user_id")
);

CREATE INDEX "ai_cost_daily_usage_usage_date_feature_model_idx"
ON "ai_cost_daily_usage"("usage_date", "feature", "model");

CREATE INDEX "action_advice_cache_expires_at_idx"
ON "action_advice_cache"("expires_at");

ALTER TABLE "ai_cost_daily_usage"
ADD CONSTRAINT "ai_cost_daily_usage_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "action_advice_cache"
ADD CONSTRAINT "action_advice_cache_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
