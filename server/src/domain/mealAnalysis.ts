import { z } from "zod";
import { normalizeImageBase64, supportedImageBase64Schema } from "./imageBase64.js";

export { normalizeImageBase64 } from "./imageBase64.js";

export const mealTypeSchema = z.enum(["breakfast", "lunch", "dinner"]);

const mealDateSchema = z.string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine(isRealCalendarDate, { message: "mealDate must be a real calendar date." });

const timeZoneSchema = z.string().trim().min(1).max(80)
  .refine(isValidTimeZone, { message: "timeZone must be a valid IANA time zone." });

export const analyzeMealRequestSchema = z.object({
  mealType: mealTypeSchema,
  mealDate: mealDateSchema,
  recordedAt: z.string().datetime({ offset: true }),
  timeZone: timeZoneSchema,
  imageBase64: supportedImageBase64Schema
}).strict().superRefine((value, context) => {
  const localDate = localCalendarDate(value.recordedAt, value.timeZone);
  if (localDate !== null && localDate !== value.mealDate) {
    context.addIssue({
      code: "custom",
      path: ["mealDate"],
      message: "mealDate must match recordedAt in timeZone."
    });
  }
});

export const listMealRecordsQuerySchema = z.object({
  date: mealDateSchema
}).strict();

export const mealAnalysisResultSchema = z.object({
  canAnalyze: z.boolean(),
  recognition: z.string().trim().min(1).max(90),
  dietaryStructureAnalysis: z.string().trim().min(1).max(180),
  cookingMethodAnalysis: z.string().trim().min(1).max(140),
  dietaryStructureSuggestion: z.string().trim().min(1).max(160),
  cookingMethodSuggestion: z.string().trim().min(1).max(140),
  cardSummary: z.string().trim().min(1).max(90)
});

export type MealType = z.infer<typeof mealTypeSchema>;
export type MealAnalysisResult = z.infer<typeof mealAnalysisResultSchema>;

export interface MealAnalysisContext {
  mealType: MealType;
  recordedAt: string;
  timeZone: string;
  profile: {
    age: number | null;
    sex: string | null;
    heightCm: number | null;
    weightKg: number | null;
    todaySteps: number | null;
    exerciseMinutes: number | null;
    restingHeartRate: number | null;
    sleepHours: number | null;
  };
  recentBloodPressureReadings: Array<{
    systolic: number;
    diastolic: number;
    pulse: number | null;
    measuredAt: string;
  }>;
}

function isRealCalendarDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    return false;
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year
    && date.getUTCMonth() === month - 1
    && date.getUTCDate() === day;
}

function isValidTimeZone(value: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format();
    return true;
  } catch {
    return false;
  }
}

function localCalendarDate(recordedAt: string, timeZone: string): string | null {
  if (!isValidTimeZone(timeZone)) {
    return null;
  }

  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(new Date(recordedAt));
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;
  return year && month && day ? `${year}-${month}-${day}` : null;
}
