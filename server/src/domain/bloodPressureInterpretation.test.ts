import assert from "node:assert/strict";
import test from "node:test";
import { makeRuleBasedInterpretation, normalizeInterpretationResult } from "./bloodPressureInterpretation.js";

function reading(systolicBp: number, diastolicBp: number, overrides: Record<string, unknown> = {}) {
  return {
    systolicBp,
    diastolicBp,
    measurementTime: "2026-07-21T08:00:00.000Z",
    ...overrides
  };
}

test("blood pressure category boundaries are explicit and stable", () => {
  assert.equal(makeRuleBasedInterpretation(reading(90, 60)).category, "normal");
  assert.equal(makeRuleBasedInterpretation(reading(120, 79)).category, "borderline");
  assert.equal(makeRuleBasedInterpretation(reading(119, 80)).category, "borderline");
  assert.equal(makeRuleBasedInterpretation(reading(135, 84)).category, "high_home");
  assert.equal(makeRuleBasedInterpretation(reading(134, 85)).category, "high_home");
  assert.equal(makeRuleBasedInterpretation(reading(180, 90)).category, "urgent");
  assert.equal(makeRuleBasedInterpretation(reading(150, 120)).category, "urgent");
  assert.equal(makeRuleBasedInterpretation(reading(89, 65)).category, "low");
  assert.equal(makeRuleBasedInterpretation(reading(100, 59)).category, "low");
});

test("invalid or reversed readings return insufficient data", () => {
  const result = makeRuleBasedInterpretation(reading(80, 90));
  assert.equal(result.category, "insufficient_data");
  assert.equal(result.historySummary.readingCount, 0);
  assert.match(result.summary, /确认/);
});

test("three recorded days are counted as three and never inflated to seven", () => {
  const result = makeRuleBasedInterpretation(reading(138, 88, {
    recentBpReadings: [
      { systolicBp: 136, diastolicBp: 86, measurementTime: "2026-07-18T08:00:00.000Z" },
      { systolicBp: 134, diastolicBp: 84, measurementTime: "2026-07-20T08:00:00.000Z" }
    ]
  }));

  assert.equal(result.historySummary.readingCount, 3);
  assert.equal(result.historySummary.daysCovered, 3);
  assert.equal(result.reasons.some((value) => /7天/.test(value)), false);
  assert.match(result.reasons.join(" "), /近 3 次平均/);
});

test("an urgent symptom raises safety severity even with an otherwise normal reading", () => {
  const result = makeRuleBasedInterpretation(reading(118, 76, { symptoms: ["chest_pain"] }));
  assert.equal(result.category, "normal");
  assert.equal(result.severity, "urgent");
  assert.match(result.safetyNote, /立即寻求急诊帮助/);
  assert.match(result.nextSteps[0] ?? "", /立即寻求急诊帮助/);
});

test("OpenAI wording can never change rule-owned category or severity", () => {
  const base = makeRuleBasedInterpretation(reading(180, 100));
  const normalized = normalizeInterpretationResult({
    category: "normal",
    severity: "reassuring",
    title: "请继续观察",
    summary: "模型生成的摘要"
  }, base);

  assert.equal(normalized.category, "urgent");
  assert.equal(normalized.severity, "urgent");
  assert.equal(normalized.title, "请继续观察");
});

test("context notes stay supportive and non-diagnostic", () => {
  const result = makeRuleBasedInterpretation(reading(128, 82, {
    age: 65,
    heightCm: 165,
    weightKg: 75,
    todaySteps: 1200,
    restingHeartRate: 95,
    averageSleepHoursLast7Days: 5.2
  }));
  const text = [result.summary, ...result.personalContextNotes, ...result.nextSteps].join(" ");

  assert.doesNotMatch(text, /确诊|患有高血压|停药|加药|减药|换药/);
  assert.match(text, /睡眠偏少/);
  assert.match(text, /今日步数偏少/);
});
