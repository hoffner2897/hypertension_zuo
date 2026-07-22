-- CreateEnum
CREATE TYPE "ExerciseActionStatus" AS ENUM ('pending', 'in_progress', 'completed', 'skipped', 'missed');

-- CreateTable
CREATE TABLE "exercise_actions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "exercise_id" VARCHAR(100) NOT NULL,
    "title" VARCHAR(100) NOT NULL,
    "scene" VARCHAR(80) NOT NULL,
    "energy" VARCHAR(80) NOT NULL,
    "contexts" TEXT[] NOT NULL,
    "scheduled_start_at" TIMESTAMPTZ(3) NOT NULL,
    "duration_minutes" INTEGER NOT NULL,
    "status" "ExerciseActionStatus" NOT NULL,
    "completed_at" TIMESTAMPTZ(3),
    "movement_advice" TEXT NOT NULL,
    "intensity_advice" TEXT NOT NULL,
    "local_day" VARCHAR(10) NOT NULL,
    "client_updated_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "exercise_actions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "exercise_actions_user_id_local_day_scheduled_start_at_idx"
ON "exercise_actions"("user_id", "local_day", "scheduled_start_at");

-- AddForeignKey
ALTER TABLE "exercise_actions"
ADD CONSTRAINT "exercise_actions_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
