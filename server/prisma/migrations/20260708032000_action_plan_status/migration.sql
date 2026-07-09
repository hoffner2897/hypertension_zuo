ALTER TABLE "action_plans"
ADD COLUMN "status" TEXT NOT NULL DEFAULT 'planned',
ADD COLUMN "status_note" TEXT,
ADD COLUMN "adjusted_at" TIMESTAMPTZ(3);
