CREATE TABLE "action_plans" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "recommendation_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "summary" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "duration_minutes" INTEGER NOT NULL,
    "intensity" TEXT NOT NULL,
    "scheduled_for" DATE NOT NULL,
    "reminder_time" TEXT,
    "context" TEXT,
    "steps" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "completed_at" TIMESTAMPTZ(3),
    "deleted_at" TIMESTAMPTZ(3),

    CONSTRAINT "action_plans_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "action_plans_user_id_client_id_key" ON "action_plans"("user_id", "client_id");
CREATE INDEX "action_plans_user_id_scheduled_for_idx" ON "action_plans"("user_id", "scheduled_for");
CREATE INDEX "action_plans_user_id_deleted_at_idx" ON "action_plans"("user_id", "deleted_at");

ALTER TABLE "action_plans" ADD CONSTRAINT "action_plans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
