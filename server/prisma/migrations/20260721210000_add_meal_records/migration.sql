-- CreateEnum
CREATE TYPE "MealType" AS ENUM ('breakfast', 'lunch', 'dinner');

-- CreateTable
CREATE TABLE "meal_records" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "meal_type" "MealType" NOT NULL,
    "meal_date" VARCHAR(10) NOT NULL,
    "analysis" TEXT NOT NULL,
    "similar_suggestion" TEXT NOT NULL,
    "card_summary" TEXT NOT NULL,
    "recorded_at" TIMESTAMPTZ(3) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "meal_records_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "meal_records_meal_date_check" CHECK (
        "meal_date" ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        AND "meal_date" = to_char("meal_date"::date, 'YYYY-MM-DD')
    )
);

-- CreateIndex
CREATE UNIQUE INDEX "meal_records_user_id_meal_date_meal_type_key"
ON "meal_records"("user_id", "meal_date", "meal_type");

-- CreateIndex
CREATE INDEX "meal_records_user_id_recorded_at_idx"
ON "meal_records"("user_id", "recorded_at");

-- AddForeignKey
ALTER TABLE "meal_records"
ADD CONSTRAINT "meal_records_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
