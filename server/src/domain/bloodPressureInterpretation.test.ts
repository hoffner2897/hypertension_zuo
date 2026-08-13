import assert from "node:assert/strict";
import test from "node:test";
import { makeRuleBasedInterpretation, normalizeInterpretationResult } from "./bloodPressureInterpretation.js";

function reading(systolicBp: number, diastolicBp: number, overrides: Record<string, unknown> = {}) {
  return { systolicBp, diastolicBp, measurementTime: "2026-07-21T08:00:00.000Z", timeZone: "UTC", ...overrides };
}

test("blood pressure category boundaries are stable", () => {
  assert.equal(makeRuleBasedInterpretation(reading(90, 60)).category, "normal");
  assert.equal(makeRuleBasedInterpretation(reading(120, 79)).category, "borderline");
  assert.equal(makeRuleBasedInterpretation(reading(135, 84)).category, "high_home");
  assert.equal(makeRuleBasedInterpretation(reading(180, 90)).category, "urgent");
  assert.equal(makeRuleBasedInterpretation(reading(89, 65)).category, "low");
});

test("repeat advice starts at the configured grade-two boundary", () => {
  const monitored = makeRuleBasedInterpretation(reading(159, 99));
  assert.equal(monitored.category, "high_home");
  assert.equal(monitored.severity, "watch");
  assert.match(monitored.nextSteps[0] ?? "", /每日监测/);
  assert.doesNotMatch(monitored.nextSteps.join(" "), /复测/);

  const systolicBoundary = makeRuleBasedInterpretation(reading(160, 99));
  assert.equal(systolicBoundary.severity, "repeat");
  assert.match(systolicBoundary.nextSteps[0] ?? "", /复测/);

  const diastolicBoundary = makeRuleBasedInterpretation(reading(150, 100));
  assert.equal(diastolicBoundary.severity, "repeat");
  assert.match(diastolicBoundary.nextSteps[0] ?? "", /复测/);

  const urgent = makeRuleBasedInterpretation(reading(180, 120));
  assert.equal(urgent.severity, "urgent");
  assert.match(urgent.nextSteps.join(" "), /立即复测/);
});

test("a single mildly high reading stays daily monitoring with medical context", () => {
  const result = makeRuleBasedInterpretation(reading(150, 95, {
    medicalContext: { knownHypertension: true, medications: "已按医嘱用药" }
  }));
  assert.equal(result.severity, "watch");
  assert.doesNotMatch(result.nextSteps.join(" "), /复测|立即随访/);
  assert.match(result.nextSteps.join(" "), /每日监测/);
});

test("invalid readings return insufficient data", () => {
  const result = makeRuleBasedInterpretation(reading(80, 90));
  assert.equal(result.category, "insufficient_data");
  assert.match(result.bloodPressureSituation[0] ?? "", /确认/);
});

test("trend averages first average each calendar day", () => {
  const result = makeRuleBasedInterpretation(reading(140, 90, {
    recentBpReadings: [
      { systolicBp: 120, diastolicBp: 70, measurementTime: "2026-07-21T09:00:00.000Z" },
      { systolicBp: 130, diastolicBp: 80, measurementTime: "2026-07-20T08:00:00.000Z" },
      { systolicBp: 150, diastolicBp: 90, measurementTime: "2026-07-19T08:00:00.000Z" },
      { systolicBp: 110, diastolicBp: 70, measurementTime: "2026-07-18T08:00:00.000Z" }
    ]
  }));
  const threeDay = result.trendComparisons.find((item) => item.days === 3);
  assert.deepEqual(threeDay?.currentAverage, { systolic: 137, diastolic: 83 });
  assert.deepEqual(threeDay?.previousAverage, { systolic: 110, diastolic: 70 });
  assert.match(result.bloodPressureSituation.join(" "), /3日/);
});

test("urgent symptoms retain emergency wording", () => {
  const result = makeRuleBasedInterpretation(reading(118, 76, { symptoms: ["chest_pain"] }));
  assert.equal(result.severity, "urgent");
  assert.match(result.safetyNote, /立即寻求急诊帮助/);
});

test("OpenAI can never change rule-owned category or severity", () => {
  const base = makeRuleBasedInterpretation(reading(180, 100));
  const normalized = normalizeInterpretationResult({
    category: "normal", severity: "reassuring",
    bloodPressureSituation: ["本次：模型润色"], reasons: ["原因：模型润色"], nextSteps: ["现在：模型润色"]
  }, base);
  assert.equal(normalized.category, "urgent");
  assert.equal(normalized.severity, "urgent");
  assert.deepEqual(normalized.bloodPressureSituation, ["本次：模型润色"]);
});

test("OpenAI cannot request repeat below grade-two range", () => {
  const base = makeRuleBasedInterpretation(reading(150, 95));
  const normalized = normalizeInterpretationResult({
    category: "high_home",
    severity: "repeat",
    bloodPressureSituation: ["本次：模型润色"],
    reasons: ["原因：模型润色"],
    nextSteps: ["现在：安静休息后复测。", "观察：按计划每日监测。"]
  }, base);

  assert.notEqual(normalized.severity, "repeat");
  assert.doesNotMatch(normalized.nextSteps.join(" "), /复测/);
  assert.match(normalized.nextSteps.join(" "), /每日监测/);
});
