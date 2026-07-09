-- AlterTable
ALTER TABLE "user_profiles" ADD COLUMN     "daily_steps" INTEGER,
ADD COLUMN     "exercise_minutes" INTEGER,
ADD COLUMN     "health_data_source" TEXT,
ADD COLUMN     "health_data_synced_at" TIMESTAMPTZ(3),
ADD COLUMN     "height_cm" DECIMAL(5,2),
ADD COLUMN     "resting_heart_rate" INTEGER,
ADD COLUMN     "sleep_hours" DECIMAL(4,2),
ADD COLUMN     "weight_kg" DECIMAL(5,2);
