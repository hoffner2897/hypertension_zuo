import { z } from "zod";

export const actionObservationSchema = z.object({
  id: z.string().uuid(),
  type: z.enum(["blood_pressure", "diet", "exercise", "other"]),
  title: z.string().trim().min(1).max(60),
  scheduledStartAt: z.string().datetime({ offset: true }),
  durationMinutes: z.number().int().min(1).max(240).nullable().default(null),
  status: z.enum(["pending", "in_progress", "completed", "skipped", "missed"]),
  completedAt: z.string().datetime({ offset: true }).nullable().default(null)
}).strict();

export const actionTrendSuggestionRequestSchema = z.object({
  now: z.string().datetime({ offset: true }),
  timeZone: z.string().trim().min(1).max(64).refine(isValidTimeZone, {
    message: "timeZone must be a valid IANA time zone."
  }),
  todayActions: z.array(actionObservationSchema).max(30),
  recentActions: z.array(actionObservationSchema).max(100).default([])
}).strict().superRefine((value, context) => {
  const ids = new Set<string>();
  for (const action of value.todayActions) {
    if (ids.has(action.id)) {
      context.addIssue({
        code: "custom",
        path: ["todayActions"],
        message: "todayActions must not contain duplicate ids."
      });
      return;
    }
    ids.add(action.id);
  }
});

export const actionTrendSuggestionSchema = z.object({
  targetActionId: z.string().uuid(),
  kind: z.enum(["reschedule", "shorten", "switch_exercise", "resolve_conflict"]),
  message: z.string().trim().min(1).max(52),
  proposedStartTime: z.string().regex(/^(?:[01]\d|2[0-3]):(?:00|30)$/).nullable(),
  proposedDurationMinutes: z.union([z.literal(10), z.literal(15), z.literal(20), z.literal(30)]).nullable(),
  proposedExerciseName: z.string().trim().min(1).max(20).nullable()
}).strict();

export const actionTrendSuggestionResponseSchema = z.object({
  status: z.enum(["ready", "no_suggestions"]),
  source: z.enum(["openai", "rule_based"]),
  evidenceDays: z.number().int().min(0).max(31),
  suggestions: z.array(actionTrendSuggestionSchema).max(2),
  dataNote: z.string().trim().min(1).max(80),
  disclaimer: z.string().trim().min(1).max(100)
}).strict();

export const openAIActionTrendSelectionSchema = z.object({
  selections: z.array(z.object({
    candidateId: z.string().min(1).max(128),
    message: z.string().trim().min(1).max(52)
  }).strict()).min(1).max(2)
}).strict();

export type ActionObservation = z.infer<typeof actionObservationSchema>;
export type ActionTrendSuggestionRequest = z.infer<typeof actionTrendSuggestionRequestSchema>;
export type ActionTrendSuggestion = z.infer<typeof actionTrendSuggestionSchema>;
export type ActionTrendSuggestionResponse = z.infer<typeof actionTrendSuggestionResponseSchema>;
export type OpenAIActionTrendSelection = z.infer<typeof openAIActionTrendSelectionSchema>;

export interface TrustedActionSuggestionCandidate {
  id: string;
  actionId: string;
  kind: ActionTrendSuggestion["kind"];
  fallbackMessage: string;
  evidenceDays: number;
  priority: number;
  proposedStartTime: string | null;
  proposedDurationMinutes: 10 | 15 | 20 | 30 | null;
  proposedExerciseName: string | null;
}

export interface TrustedActionSuggestionPlan {
  evidenceDays: number;
  candidates: TrustedActionSuggestionCandidate[];
}

const adjustableStatuses = new Set<ActionObservation["status"]>(["pending", "in_progress", "missed"]);
const unsuccessfulStatuses = new Set<ActionObservation["status"]>(["missed", "skipped"]);
const oneDayUnsupportedPhrases = /最近|近期|近来|近几天|这几天|过去几天|多日|多天|多次|经常|常常|频繁|老是|总是|长期|完成率|趋势/;
const unsafeHealthPhrases = /确诊|患有高血压|高血压患者|服药|停药|加药|减药|换药|药物治疗|处方/;

export const actionSuggestionDisclaimer = "行动调整建议仅用于帮助安排日常计划，不替代专业医疗建议。";

export function buildTrustedActionSuggestionPlan(input: ActionTrendSuggestionRequest): TrustedActionSuggestionPlan {
  const evidenceDays = countEvidenceDays(input);
  const candidates: TrustedActionSuggestionCandidate[] = [];
  const adjustableTodayActions = input.todayActions.filter((action) => adjustableStatuses.has(action.status));

  for (const action of adjustableTodayActions) {
    const matchingHistory = deduplicateObservations([...input.recentActions, ...input.todayActions])
      .filter((observation) => observation.type === action.type && normalizeTitle(observation.title) === normalizeTitle(action.title));
    const matchingDays = countObservationDays(matchingHistory, input.timeZone);
    const unsuccessfulCount = matchingHistory.filter((observation) => unsuccessfulStatuses.has(observation.status)).length;

    if (matchingDays >= 3 && matchingHistory.length >= 3 && unsuccessfulCount >= 2 && unsuccessfulCount / matchingHistory.length >= 0.5) {
      candidates.push({
        id: `trend-reschedule:${action.id}`,
        actionId: action.id,
        kind: "reschedule",
        fallbackMessage: limitMessage(`近${matchingDays}天“${safeActionTitle(action)}”有${unsuccessfulCount}次未完成，可尝试调整时间。`),
        evidenceDays: matchingDays,
        priority: 120 + unsuccessfulCount,
        proposedStartTime: null,
        proposedDurationMinutes: null,
        proposedExerciseName: null
      });

      if (action.type === "exercise") {
        candidates.push({
          id: `trend-switch:${action.id}`,
          actionId: action.id,
          kind: "switch_exercise",
          fallbackMessage: limitMessage(`近${matchingDays}天“${safeActionTitle(action)}”较难完成，可尝试更低门槛的运动。`),
          evidenceDays: matchingDays,
          priority: 110 + unsuccessfulCount,
          proposedStartTime: null,
          proposedDurationMinutes: null,
          proposedExerciseName: replacementExercise(action.title)
        });
      }
    }

    if (action.status === "missed") {
      candidates.push({
        id: `today-reschedule:${action.id}`,
        actionId: action.id,
        kind: "reschedule",
        fallbackMessage: limitMessage(`今天${formatTime(action.scheduledStartAt, input.timeZone)}的“${safeActionTitle(action)}”尚未完成，可调整到更方便的时间。`),
        evidenceDays: 1,
        priority: 90,
        proposedStartTime: null,
        proposedDurationMinutes: null,
        proposedExerciseName: null
      });

      if (action.type === "exercise" && (action.durationMinutes ?? 0) >= 15) {
        candidates.push({
          id: `today-shorten:${action.id}`,
          actionId: action.id,
          kind: "shorten",
          fallbackMessage: limitMessage(`今天的“${safeActionTitle(action)}”尚未完成，可缩短时长后再尝试。`),
          evidenceDays: 1,
          priority: 82,
          proposedStartTime: null,
          proposedDurationMinutes: shorterDuration(action.durationMinutes),
          proposedExerciseName: null
        });
      }

      if (action.type === "exercise") {
        candidates.push({
          id: `today-switch:${action.id}`,
          actionId: action.id,
          kind: "switch_exercise",
          fallbackMessage: limitMessage(`今天的“${safeActionTitle(action)}”尚未完成，可尝试更易开始的低门槛运动。`),
          evidenceDays: 1,
          priority: 78,
          proposedStartTime: null,
          proposedDurationMinutes: null,
          proposedExerciseName: replacementExercise(action.title)
        });
      }
    }
  }

  candidates.push(...makeConflictCandidates(adjustableTodayActions, input.timeZone));

  return {
    evidenceDays,
    candidates: deduplicateCandidates(candidates)
      .sort((left, right) => right.priority - left.priority || left.id.localeCompare(right.id))
      .slice(0, 12)
  };
}

export function makeRuleBasedSuggestions(
  candidates: TrustedActionSuggestionCandidate[]
): ActionTrendSuggestion[] {
  return candidates.slice(0, 2).map((candidate) => candidateToSuggestion(candidate));
}

export function resolveOpenAISelections(
  value: unknown,
  candidates: TrustedActionSuggestionCandidate[]
): ActionTrendSuggestion[] {
  const parsed = openAIActionTrendSelectionSchema.parse(value);
  const candidatesById = new Map(candidates.map((candidate) => [candidate.id, candidate]));
  const seen = new Set<string>();
  const suggestions: ActionTrendSuggestion[] = [];

  for (const selection of parsed.selections) {
    const candidate = candidatesById.get(selection.candidateId);
    if (!candidate || seen.has(candidate.id)) {
      continue;
    }

    seen.add(candidate.id);
    const proposedMessage = normalizeMessage(selection.message);
    const message = isAllowedPolish(proposedMessage, candidate)
      ? proposedMessage
      : candidate.fallbackMessage;
    suggestions.push(candidateToSuggestion(candidate, message));
  }

  if (suggestions.length === 0) {
    throw new Error("OpenAI did not select a trusted action suggestion candidate.");
  }

  return suggestions.slice(0, 2);
}

function makeConflictCandidates(
  actions: ActionObservation[],
  timeZone: string
): TrustedActionSuggestionCandidate[] {
  const sorted = [...actions].sort((left, right) => Date.parse(left.scheduledStartAt) - Date.parse(right.scheduledStartAt));
  const candidates: TrustedActionSuggestionCandidate[] = [];

  for (let index = 1; index < sorted.length; index += 1) {
    const previous = sorted[index - 1];
    const current = sorted[index];
    if (!previous || !current) {
      continue;
    }

    const previousEnd = Date.parse(previous.scheduledStartAt) + (previous.durationMinutes ?? 1) * 60_000;
    const currentStart = Date.parse(current.scheduledStartAt);
    if (currentStart >= previousEnd) {
      continue;
    }

    candidates.push({
      id: `today-conflict:${current.id}`,
      actionId: current.id,
      kind: "resolve_conflict",
      fallbackMessage: limitMessage(`今天“${safeActionTitle(previous)}”和“${safeActionTitle(current)}”时间重叠，可调整后者的开始时间。`),
      evidenceDays: 1,
      priority: 100,
      proposedStartTime: null,
      proposedDurationMinutes: null,
      proposedExerciseName: null
    });
  }

  return candidates;
}

function deduplicateCandidates(candidates: TrustedActionSuggestionCandidate[]): TrustedActionSuggestionCandidate[] {
  const bestByActionAndKind = new Map<string, TrustedActionSuggestionCandidate>();
  for (const candidate of candidates) {
    const key = `${candidate.actionId}:${candidate.kind}`;
    const existing = bestByActionAndKind.get(key);
    if (!existing || candidate.priority > existing.priority) {
      bestByActionAndKind.set(key, candidate);
    }
  }
  return [...bestByActionAndKind.values()];
}

function deduplicateObservations(observations: ActionObservation[]): ActionObservation[] {
  const unique = new Map<string, ActionObservation>();
  for (const observation of observations) {
    unique.set(`${observation.id}:${observation.scheduledStartAt}`, observation);
  }
  return [...unique.values()];
}

function candidateToSuggestion(
  candidate: TrustedActionSuggestionCandidate,
  message = candidate.fallbackMessage
): ActionTrendSuggestion {
  return {
    targetActionId: candidate.actionId,
    kind: candidate.kind,
    message,
    proposedStartTime: candidate.proposedStartTime,
    proposedDurationMinutes: candidate.proposedDurationMinutes,
    proposedExerciseName: candidate.proposedExerciseName
  };
}

export function makeActionSuggestionDataNote(evidenceDays: number): string {
  if (evidenceDays <= 0) {
    return "当前没有可用于生成建议的行动记录。";
  }
  if (evidenceDays === 1) {
    return "建议仅基于今天提供的行动完成情况生成。";
  }
  return `建议基于已提供的近${evidenceDays}天行动记录生成。`;
}

function isAllowedPolish(message: string, candidate: TrustedActionSuggestionCandidate): boolean {
  if (!message || message.length > 52 || unsafeHealthPhrases.test(message)) {
    return false;
  }
  if (candidate.evidenceDays < 3 && oneDayUnsupportedPhrases.test(message)) {
    return false;
  }
  return true;
}

function normalizeMessage(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function normalizeTitle(value: string): string {
  return value.replace(/\s+/g, "").toLocaleLowerCase("zh-Hans");
}

function shortTitle(value: string): string {
  const normalized = normalizeMessage(value);
  return normalized.length <= 12 ? normalized : `${normalized.slice(0, 11)}…`;
}

function safeActionTitle(action: ActionObservation): string {
  if (!unsafeHealthPhrases.test(action.title) && !oneDayUnsupportedPhrases.test(action.title)) {
    return shortTitle(action.title);
  }

  switch (action.type) {
  case "blood_pressure":
    return "血压测量";
  case "diet":
    return "饮食建议";
  case "exercise":
    return "运动行动";
  case "other":
    return "当前行动";
  }
}

function limitMessage(value: string): string {
  if (value.length <= 52) {
    return value;
  }
  return `${value.slice(0, 51)}…`;
}

function shorterDuration(duration: number | null): 10 | 15 | 20 | 30 {
  if (duration === null || duration <= 15) {
    return 10;
  }
  if (duration <= 20) {
    return 15;
  }
  if (duration <= 30) {
    return 20;
  }
  return 30;
}

function replacementExercise(title: string): string {
  return title.includes("慢走") ? "原地踏步" : "慢走";
}

function countEvidenceDays(input: ActionTrendSuggestionRequest): number {
  return countObservationDays([...input.recentActions, ...input.todayActions], input.timeZone);
}

function countObservationDays(observations: ActionObservation[], timeZone: string): number {
  const days = new Set(observations.map((observation) => formatDate(observation.scheduledStartAt, timeZone)));
  return days.size;
}

function formatDate(value: string, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(new Date(value));
  const year = parts.find((part) => part.type === "year")?.value ?? "0000";
  const month = parts.find((part) => part.type === "month")?.value ?? "00";
  const day = parts.find((part) => part.type === "day")?.value ?? "00";
  return `${year}-${month}-${day}`;
}

function formatTime(value: string, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).formatToParts(new Date(value));
  const hour = parts.find((part) => part.type === "hour")?.value ?? "00";
  const minute = parts.find((part) => part.type === "minute")?.value ?? "00";
  return `${hour}:${minute}`;
}

function isValidTimeZone(value: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: value }).format();
    return true;
  } catch {
    return false;
  }
}
