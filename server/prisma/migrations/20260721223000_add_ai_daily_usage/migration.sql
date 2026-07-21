-- CreateEnum
CREATE TYPE "AIUsageFeature" AS ENUM ('bp_recognition', 'meal_analysis');

-- CreateTable
CREATE TABLE "ai_daily_usage" (
    "user_id" UUID NOT NULL,
    "usage_date" DATE NOT NULL,
    "feature" "AIUsageFeature" NOT NULL,
    "request_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "ai_daily_usage_pkey" PRIMARY KEY ("user_id", "usage_date", "feature"),
    CONSTRAINT "ai_daily_usage_request_count_check" CHECK ("request_count" >= 0)
);

-- CreateIndex
CREATE INDEX "ai_daily_usage_usage_date_feature_idx"
ON "ai_daily_usage"("usage_date", "feature");

-- AddForeignKey
ALTER TABLE "ai_daily_usage"
ADD CONSTRAINT "ai_daily_usage_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
