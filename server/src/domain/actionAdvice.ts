import { z } from "zod";
import { isEnglish, type AppLocale } from "../i18n/locale.js";

export const actionAdviceSchema = z.object({
  diet: z.object({
    structure: z.string().trim().min(1).max(360),
    cooking: z.string().trim().min(1).max(360)
  }).strict(),
  exercise: z.object({
    timing: z.string().trim().min(1).max(360),
    type: z.string().trim().min(1).max(360)
  }).strict()
}).strict();

export type ActionAdvice = z.infer<typeof actionAdviceSchema>;

export interface ActionAdviceMeal {
  mealType: string;
  mealDate: string;
  recognition: string | null;
  dietaryStructureAnalysis: string | null;
  cookingMethodAnalysis: string | null;
  dietaryStructureSuggestion: string | null;
  cookingMethodSuggestion: string | null;
}

export interface ActionAdviceExercise {
  id: string;
  title: string;
  localDay: string;
  scheduledStartAt: string;
  durationMinutes: number;
  actualDurationMinutes: number | null;
  status: string;
}

export interface ActionAdviceEvidence {
  locale: AppLocale;
  timeZone: string;
  meals: ActionAdviceMeal[];
  exercises: ActionAdviceExercise[];
  exerciseSummary: {
    plannedCount: number;
    completedCount: number;
    completionRatePercent: number | null;
    averageActualDurationMinutes: number | null;
    byTimeBucket: Array<{ bucket: string; planned: number; completed: number; completionRatePercent: number; averageActualDurationMinutes: number | null }>;
    byType: Array<{ title: string; planned: number; completed: number; completionRatePercent: number; averageActualDurationMinutes: number | null }>;
  };
}

export function buildActionAdviceEvidence(timeZone: string, meals: ActionAdviceMeal[], exercises: ActionAdviceExercise[], locale: AppLocale = "zh-Hans"): ActionAdviceEvidence {
  const uniqueExercises = deduplicateExercises(exercises);
  const completed = uniqueExercises.filter((item) => item.status === "completed");
  const actualDurations = completed.map((item) => item.actualDurationMinutes ?? item.durationMinutes).filter((value) => value > 0);
  return {
    locale,
    timeZone,
    meals,
    exercises: uniqueExercises,
    exerciseSummary: {
      plannedCount: uniqueExercises.length,
      completedCount: completed.length,
      completionRatePercent: rate(completed.length, uniqueExercises.length),
      averageActualDurationMinutes: actualDurations.length > 0 ? Math.round(actualDurations.reduce((sum, value) => sum + value, 0) / actualDurations.length) : null,
      byTimeBucket: groupStats(uniqueExercises, (item) => timeBucket(item.scheduledStartAt, timeZone, locale)).map(([bucket, values]) => ({
        bucket, planned: values.length, completed: values.filter((item) => item.status === "completed").length,
        completionRatePercent: rate(values.filter((item) => item.status === "completed").length, values.length) ?? 0,
        averageActualDurationMinutes: averageCompletedDuration(values)
      })),
      byType: groupStats(uniqueExercises, (item) => item.title).map(([title, values]) => ({
        title, planned: values.length, completed: values.filter((item) => item.status === "completed").length,
        completionRatePercent: rate(values.filter((item) => item.status === "completed").length, values.length) ?? 0,
        averageActualDurationMinutes: averageCompletedDuration(values)
      }))
    }
  };
}

export function makeRuleBasedActionAdvice(evidence: ActionAdviceEvidence): ActionAdvice {
  if (isEnglish(evidence.locale)) return makeRuleBasedActionAdviceEnglish(evidence);
  const meal = evidence.meals[0];
  const summary = evidence.exerciseSummary;
  const bestTime = [...summary.byTimeBucket].sort((a, b) => b.completionRatePercent - a.completionRatePercent || b.completed - a.completed)[0];
  const bestType = [...summary.byType].sort((a, b) => b.completionRatePercent - a.completionRatePercent || b.completed - a.completed)[0];
  const durationPhrase = bestTime?.averageActualDurationMinutes ? `，通常完成约 ${bestTime.averageActualDurationMinutes} 分钟` : "";

  return {
    diet: {
      structure: meal ? oneOrTwoSentences(meal.dietaryStructureSuggestion ?? meal.dietaryStructureAnalysis ?? `已记录${meal.recognition ?? "本次餐食"}，可继续保持主食、蔬菜和蛋白质的搭配。`) : "目前没有餐食记录；完成一次餐食记录后，这里会显示饮食结构建议。",
      cooking: meal ? oneOrTwoSentences(meal.cookingMethodSuggestion ?? meal.cookingMethodAnalysis ?? "继续优先选择少盐、少油的烹饪方式。") : "目前没有可分析的烹饪方式；记录餐食后再提供建议。"
    },
    exercise: {
      timing: summary.plannedCount === 0 ? "目前没有运动记录；完成一次运动安排后，这里会显示时段建议。" : bestTime ? `${bestTime.bucket}已安排 ${bestTime.planned} 次、完成 ${bestTime.completed} 次${durationPhrase}。接下来可以优先保留这个时段。` : `已安排 ${summary.plannedCount} 次运动，可以先保持当前时段并观察执行感受。`,
      type: summary.plannedCount === 0 ? "目前没有运动记录；生成或记录运动后再提供类型建议。" : bestType ? `${bestType.title}已安排 ${bestType.planned} 次、完成 ${bestType.completed} 次。接下来可以优先保留更容易开始和完成的运动。` : "可以优先选择更容易开始和完成的轻量运动。"
    }
  };
}

function makeRuleBasedActionAdviceEnglish(evidence: ActionAdviceEvidence): ActionAdvice {
  const meal = evidence.meals[0];
  const summary = evidence.exerciseSummary;
  const bestTime = [...summary.byTimeBucket].sort((a, b) => b.completionRatePercent - a.completionRatePercent || b.completed - a.completed)[0];
  const bestType = [...summary.byType].sort((a, b) => b.completionRatePercent - a.completionRatePercent || b.completed - a.completed)[0];
  const durationPhrase = bestTime?.averageActualDurationMinutes ? `, usually for about ${bestTime.averageActualDurationMinutes} minutes` : "";

  return {
    diet: {
      structure: meal
        ? "Use the latest recorded meal to keep a balanced mix of staple foods, vegetables, and protein."
        : "There are no meal records yet. Record one meal to receive a dietary-structure suggestion.",
      cooking: meal
        ? "Continue to favor lower-salt, lower-oil cooking methods based on the latest recorded meal."
        : "There is no cooking-method record to analyze yet. Record a meal to receive a suggestion."
    },
    exercise: {
      timing: summary.plannedCount === 0
        ? "There are no exercise records yet. Schedule one activity to receive a timing suggestion."
        : bestTime
          ? `${bestTime.bucket}: ${bestTime.planned} planned and ${bestTime.completed} completed${durationPhrase}. Consider keeping this time period.`
          : `${summary.plannedCount} activities were scheduled. Keep the current timing for now and observe how easy it is to follow.`,
      type: summary.plannedCount === 0
        ? "There are no exercise records yet. Generate or record an activity to receive a type suggestion."
        : bestType
          ? `${bestType.title}: ${bestType.planned} planned and ${bestType.completed} completed. Prioritize activities that are easier to start and finish.`
          : "Prioritize light activities that feel easy to start and complete."
    }
  };
}

export function normalizeActionAdvice(value: unknown, fallback: ActionAdvice): ActionAdvice {
  const parsed = actionAdviceSchema.safeParse(value);
  if (!parsed.success) return fallback;
  return {
    diet: {
      structure: oneOrTwoSentences(parsed.data.diet.structure),
      cooking: oneOrTwoSentences(parsed.data.diet.cooking)
    },
    exercise: {
      timing: oneOrTwoSentences(parsed.data.exercise.timing),
      type: oneOrTwoSentences(parsed.data.exercise.type)
    }
  };
}

function rate(completed: number, planned: number): number | null { return planned > 0 ? Math.round(completed / planned * 100) : null; }
function averageCompletedDuration(items: ActionAdviceExercise[]): number | null {
  const values = items
    .filter((item) => item.status === "completed")
    .map((item) => item.actualDurationMinutes ?? item.durationMinutes)
    .filter((value) => value > 0);
  return values.length > 0 ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) : null;
}
function deduplicateExercises(items: ActionAdviceExercise[]): ActionAdviceExercise[] {
  const byId = new Map<string, ActionAdviceExercise>();
  for (const item of items) {
    const existing = byId.get(item.id);
    if (!existing || existing.actualDurationMinutes == null) byId.set(item.id, item);
  }
  return [...byId.values()];
}
function groupStats<T>(items: T[], key: (item: T) => string): Array<[string, T[]]> {
  const groups = new Map<string, T[]>();
  for (const item of items) groups.set(key(item), [...(groups.get(key(item)) ?? []), item]);
  return [...groups.entries()];
}
function timeBucket(value: string, timeZone: string, locale: AppLocale): string {
  const hour = Number(new Intl.DateTimeFormat("en-GB", { timeZone, hour: "2-digit", hourCycle: "h23" }).format(new Date(value)));
  if (isEnglish(locale)) {
    if (hour < 5) return "Overnight"; if (hour < 11) return "Morning"; if (hour < 14) return "Midday"; if (hour < 18) return "Afternoon"; return "Evening";
  }
  if (hour < 5) return "夜间"; if (hour < 11) return "上午"; if (hour < 14) return "中午"; if (hour < 18) return "下午"; return "晚上";
}
function oneOrTwoSentences(value: string): string {
  const text = value.replace(/\s+/g, " ").trim();
  const separator = /\p{Script=Han}/u.test(text) ? "" : " ";
  const sentences = text.split(/(?<=[。！？.!?])/).filter(Boolean).slice(0, 2).join(separator);
  const result = sentences || text;
  return result.length <= 360 ? result : `${result.slice(0, 359)}…`;
}
