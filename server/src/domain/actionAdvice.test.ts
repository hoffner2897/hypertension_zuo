import assert from "node:assert/strict";
import test from "node:test";
import { buildActionAdviceEvidence, makeRuleBasedActionAdvice, normalizeActionAdvice } from "./actionAdvice.js";

test("one exercise record produces a concrete conclusion instead of an insufficient-data message", () => {
  const evidence = buildActionAdviceEvidence("Europe/London", [], [{
    id: "11111111-1111-4111-8111-111111111111",
    title: "适度快走",
    localDay: "2026-08-13",
    scheduledStartAt: "2026-08-13T18:00:00.000Z",
    durationMinutes: 15,
    actualDurationMinutes: 13,
    status: "completed"
  }]);
  const result = makeRuleBasedActionAdvice(evidence);
  assert.match(result.exercise.timing, /晚上已安排 1 次、完成 1 次/);
  assert.match(result.exercise.type, /适度快走已安排 1 次、完成 1 次/);
  assert.doesNotMatch(`${result.exercise.timing}${result.exercise.type}`, /记录还比较少|数据不足/);
});

test("English action advice uses English evidence labels and conclusions", () => {
  const evidence = buildActionAdviceEvidence("Europe/London", [], [{
    id: "33333333-3333-4333-8333-333333333333",
    title: "Easy walking",
    localDay: "2026-08-13",
    scheduledStartAt: "2026-08-13T18:00:00.000Z",
    durationMinutes: 15,
    actualDurationMinutes: 15,
    status: "completed"
  }], "en");
  const result = makeRuleBasedActionAdvice(evidence);
  assert.match(result.exercise.timing, /planned/i);
  assert.match(result.exercise.type, /completed/i);
  assert.doesNotMatch(JSON.stringify(result), /[\u4e00-\u9fff]/);
});

test("duplicate client and server exercise records count only once", () => {
  const duplicate = {
    id: "22222222-2222-4222-8222-222222222222",
    title: "原地踏步",
    localDay: "2026-08-13",
    scheduledStartAt: "2026-08-13T10:00:00.000Z",
    durationMinutes: 20,
    status: "completed"
  };
  const evidence = buildActionAdviceEvidence("Europe/London", [], [
    { ...duplicate, actualDurationMinutes: 18 },
    { ...duplicate, actualDurationMinutes: null }
  ]);
  assert.equal(evidence.exerciseSummary.plannedCount, 1);
  assert.equal(evidence.exerciseSummary.completedCount, 1);
  assert.equal(evidence.exerciseSummary.averageActualDurationMinutes, 18);
});

test("AI advice is bounded to two sentences per field", () => {
  const fallback = makeRuleBasedActionAdvice(buildActionAdviceEvidence("UTC", [], []));
  const normalized = normalizeActionAdvice({
    diet: {
      structure: "第一句。第二句。第三句。",
      cooking: "第一句。第二句。第三句。"
    },
    exercise: {
      timing: "第一句。第二句。第三句。",
      type: "第一句。第二句。第三句。"
    }
  }, fallback);
  assert.equal(normalized.diet.structure, "第一句。第二句。");
  assert.equal(normalized.exercise.timing, "第一句。第二句。");
});
