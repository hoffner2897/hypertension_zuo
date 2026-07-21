import assert from "node:assert/strict";
import test from "node:test";
import {
  actionTrendSuggestionRequestSchema,
  actionTrendSuggestionResponseSchema,
  buildTrustedActionSuggestionPlan,
  makeActionSuggestionDataNote,
  makeRuleBasedSuggestions,
  resolveOpenAISelections
} from "./actionTrendSuggestions.js";

const todayActionId = "11111111-1111-4111-8111-111111111111";
const secondActionId = "22222222-2222-4222-8222-222222222222";

test("strict request parsing accepts an empty history and applies defaults", () => {
  const parsed = actionTrendSuggestionRequestSchema.parse({
    now: "2026-07-21T18:00:00.000Z",
    timeZone: "Europe/London",
    todayActions: []
  });

  assert.deepEqual(parsed.recentActions, []);
  assert.equal(buildTrustedActionSuggestionPlan(parsed).evidenceDays, 0);
  assert.equal(makeActionSuggestionDataNote(0), "当前没有可用于生成建议的行动记录。");
});

test("strict request parsing rejects unknown fields and invalid time zones", () => {
  const withUnknownField = actionTrendSuggestionRequestSchema.safeParse({
    now: "2026-07-21T18:00:00.000Z",
    timeZone: "Europe/London",
    todayActions: [],
    unexpected: true
  });
  const withInvalidTimeZone = actionTrendSuggestionRequestSchema.safeParse({
    now: "2026-07-21T18:00:00.000Z",
    timeZone: "Not/AZone",
    todayActions: []
  });

  assert.equal(withUnknownField.success, false);
  assert.equal(withInvalidTimeZone.success, false);
});

test("completed and skipped actions can be evidence but never suggestion targets", () => {
  const input = parseRequest([
    makeAction(todayActionId, "completed", "原地踏步", "2026-07-21T15:00:00.000Z"),
    makeAction(secondActionId, "skipped", "慢走", "2026-07-21T16:00:00.000Z")
  ]);

  const plan = buildTrustedActionSuggestionPlan(input);
  assert.deepEqual(plan.candidates, []);
  assert.deepEqual(makeRuleBasedSuggestions(plan.candidates), []);
});

test("one-day missed exercise creates grounded fallback candidates without trend claims", () => {
  const input = parseRequest([
    makeAction(todayActionId, "missed", "原地踏步", "2026-07-21T15:00:00.000Z", 20)
  ]);

  const plan = buildTrustedActionSuggestionPlan(input);
  const suggestions = makeRuleBasedSuggestions(plan.candidates);
  const shorten = plan.candidates.find((candidate) => candidate.kind === "shorten");

  assert.equal(plan.evidenceDays, 1);
  assert.equal(suggestions.length, 2);
  assert.ok(suggestions.every((suggestion) => suggestion.targetActionId === todayActionId));
  assert.ok(suggestions.every((suggestion) => !/最近多天|最近几天|经常|完成率|趋势/.test(suggestion.message)));
  assert.equal(shorten?.proposedDurationMinutes, 15);
  assert.ok(plan.candidates.every((candidate) => candidate.actionId === todayActionId));
});

test("untrusted action titles cannot inject unsupported trend or health wording into fallback", () => {
  const input = parseRequest([
    makeAction(todayActionId, "missed", "最近多天经常服药", "2026-07-21T15:00:00.000Z", 20)
  ]);

  const messages = makeRuleBasedSuggestions(buildTrustedActionSuggestionPlan(input).candidates)
    .map((suggestion) => suggestion.message)
    .join(" ");

  assert.doesNotMatch(messages, /最近|多天|经常|服药/);
  assert.match(messages, /运动行动/);
});

test("multi-day wording is generated only from at least three matching evidence days", () => {
  const today = makeAction(todayActionId, "pending", "原地踏步", "2026-07-21T15:00:00.000Z", 20);
  const input = actionTrendSuggestionRequestSchema.parse({
    now: "2026-07-21T12:00:00.000Z",
    timeZone: "Europe/London",
    todayActions: [today],
    recentActions: [
      makeAction(todayActionId, "missed", "原地踏步", "2026-07-18T15:00:00.000Z", 20),
      makeAction(todayActionId, "skipped", "原地踏步", "2026-07-19T15:00:00.000Z", 20),
      makeAction(todayActionId, "completed", "原地踏步", "2026-07-20T15:00:00.000Z", 20)
    ]
  });

  const plan = buildTrustedActionSuggestionPlan(input);
  const trendCandidate = plan.candidates.find((candidate) => candidate.id.startsWith("trend-reschedule:"));

  assert.equal(plan.evidenceDays, 4);
  assert.equal(trendCandidate?.evidenceDays, 4);
  assert.match(trendCandidate?.fallbackMessage ?? "", /^近4天/);
});

test("OpenAI may only select trusted candidate ids and unsafe one-day polish falls back", () => {
  const input = parseRequest([
    makeAction(todayActionId, "missed", "原地踏步", "2026-07-21T15:00:00.000Z", 20)
  ]);
  const plan = buildTrustedActionSuggestionPlan(input);
  const candidate = plan.candidates[0];
  assert.ok(candidate);

  const suggestions = resolveOpenAISelections({
    selections: [{
      candidateId: candidate.id,
      message: "最近几天经常完不成，完成率趋势很差。"
    }]
  }, plan.candidates);

  assert.equal(suggestions[0]?.message, candidate.fallbackMessage);
  assert.throws(() => resolveOpenAISelections({
    selections: [{
      candidateId: "invented-candidate",
      message: "可以调整时间。"
    }]
  }, plan.candidates));
});

test("public response contract validates nullable proposals and no-suggestion state", () => {
  const response = actionTrendSuggestionResponseSchema.parse({
    status: "no_suggestions",
    source: "rule_based",
    evidenceDays: 1,
    suggestions: [],
    dataNote: makeActionSuggestionDataNote(1),
    disclaimer: "行动调整建议仅用于帮助安排日常计划，不替代专业医疗建议。"
  });

  assert.equal(response.status, "no_suggestions");
});

function parseRequest(todayActions: ReturnType<typeof makeAction>[]) {
  return actionTrendSuggestionRequestSchema.parse({
    now: "2026-07-21T18:00:00.000Z",
    timeZone: "Europe/London",
    todayActions,
    recentActions: []
  });
}

function makeAction(
  id: string,
  status: "pending" | "in_progress" | "completed" | "skipped" | "missed",
  title: string,
  scheduledStartAt: string,
  durationMinutes = 10
) {
  return {
    id,
    type: "exercise" as const,
    title,
    scheduledStartAt,
    durationMinutes,
    status,
    completedAt: status === "completed" ? "2026-07-21T15:10:00.000Z" : null
  };
}
