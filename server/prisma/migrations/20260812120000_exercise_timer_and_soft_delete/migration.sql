ALTER TABLE "exercise_actions"
  ADD COLUMN "actual_started_at" TIMESTAMPTZ(3),
  ADD COLUMN "timer_last_resumed_at" TIMESTAMPTZ(3),
  ADD COLUMN "timer_accumulated_seconds" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "actual_ended_at" TIMESTAMPTZ(3),
  ADD COLUMN "actual_duration_seconds" INTEGER,
  ADD COLUMN "completion_mode" VARCHAR(40),
  ADD COLUMN "deleted_at" TIMESTAMPTZ(3);

CREATE INDEX "exercise_actions_user_id_deleted_at_idx"
  ON "exercise_actions"("user_id", "deleted_at");
