import assert from "node:assert/strict";
import test from "node:test";
import {
  analyzeMealRequestSchema,
  mealAnalysisResultSchema,
  normalizeImageBase64
} from "./mealAnalysis.js";
import { mealAnalysisPrompt } from "../services/openAIMealAnalysisService.js";

const jpegBase64 = "/9j/4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/Z";

test("meal input accepts a dated client payload and normalizes its transient image", () => {
  const input = analyzeMealRequestSchema.parse({
    mealType: "lunch",
    mealDate: "2026-07-21",
    recordedAt: "2026-07-21T12:30:00.000Z",
    timeZone: "Europe/London",
    imageBase64: `data:image/jpeg;base64,${jpegBase64}`
  });

  assert.equal(input.mealType, "lunch");
  assert.deepEqual(normalizeImageBase64(input.imageBase64), {
    mimeType: "image/jpeg",
    base64: jpegBase64
  });
});

test("meal input rejects impossible dates, invalid time zones, date mismatches, and fake images", () => {
  const base = {
    mealType: "lunch",
    mealDate: "2026-07-21",
    recordedAt: "2026-07-21T12:30:00.000Z",
    timeZone: "Europe/London",
    imageBase64: `data:image/jpeg;base64,${jpegBase64}`
  };

  assert.equal(analyzeMealRequestSchema.safeParse({ ...base, mealDate: "2026-02-30" }).success, false);
  assert.equal(analyzeMealRequestSchema.safeParse({ ...base, timeZone: "Not/AZone" }).success, false);
  assert.equal(analyzeMealRequestSchema.safeParse({ ...base, mealDate: "2026-07-20" }).success, false);
  assert.equal(analyzeMealRequestSchema.safeParse({
    ...base,
    imageBase64: "data:image/jpeg;base64,abcdefghijklmnopqrstuvwxyz1234567890"
  }).success, false);
});

test("meal output is bounded text and prompt contains safety requirements", () => {
  const result = mealAnalysisResultSchema.parse({
    canAnalyze: true,
    analysis: "照片中可见米饭、蔬菜和蛋白质食物。",
    similarSuggestion: "下次可少放酱汁，并增加蔬菜。",
    cardSummary: "搭配较丰富，下次可减少酱汁。"
  });

  assert.equal(result.canAnalyze, true);
  assert.match(mealAnalysisPrompt, /不得声称知道精确克数/);
  assert.match(mealAnalysisPrompt, /不诊断高血压/);
  assert.match(mealAnalysisPrompt, /照片不是食物/);
});
