-- Persist the latest Today Action tree for each participant/day and retain an
-- append-only change trail for research. Photographs are never included.
CREATE TABLE "daily_action_snapshots" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "local_day" VARCHAR(10) NOT NULL,
    "time_zone" VARCHAR(64) NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "items" JSONB NOT NULL,
    "total_count" INTEGER NOT NULL,
    "completed_count" INTEGER NOT NULL,
    "captured_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "daily_action_snapshots_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "daily_action_snapshots_counts_check"
      CHECK ("total_count" >= 0 AND "completed_count" >= 0 AND "completed_count" <= "total_count")
);

CREATE TABLE "action_events" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "local_day" VARCHAR(10) NOT NULL,
    "item_id" UUID,
    "event_type" VARCHAR(40) NOT NULL,
    "snapshot_version" INTEGER NOT NULL,
    "before_state" JSONB,
    "after_state" JSONB,
    "occurred_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "action_events_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "daily_action_snapshots_user_id_local_day_key"
  ON "daily_action_snapshots"("user_id", "local_day");
CREATE INDEX "daily_action_snapshots_local_day_updated_at_idx"
  ON "daily_action_snapshots"("local_day", "updated_at");
CREATE INDEX "action_events_user_id_local_day_occurred_at_idx"
  ON "action_events"("user_id", "local_day", "occurred_at");
CREATE INDEX "action_events_user_id_item_id_occurred_at_idx"
  ON "action_events"("user_id", "item_id", "occurred_at");

ALTER TABLE "daily_action_snapshots"
  ADD CONSTRAINT "daily_action_snapshots_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "action_events"
  ADD CONSTRAINT "action_events_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
