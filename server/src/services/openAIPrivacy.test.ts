import assert from "node:assert/strict";
import test from "node:test";
import { makeRuleBasedInterpretation } from "../domain/bloodPressureInterpretation.js";
import { makeOpenAIBPInterpretationRequestBody } from "./openAIBPInterpretationService.js";
import { makeOpenAIBPRecognitionRequestBody } from "./openAIBPRecognitionService.js";

test("blood pressure OpenAI requests explicitly disable response storage", () => {
  const recognitionRequest = makeOpenAIBPRecognitionRequestBody("privacy-test-model", {
    mimeType: "image/jpeg",
    base64: "/9j/4AAQSkZJRgABAQ=="
  });
  assert.equal(recognitionRequest.store, false);

  const interpretationInput = {
    systolicBp: 128,
    diastolicBp: 82,
    measurementTime: "2026-07-21T07:45:00.000Z"
  };
  const interpretationRequest = makeOpenAIBPInterpretationRequestBody(
    "privacy-test-model",
    interpretationInput,
    makeRuleBasedInterpretation(interpretationInput)
  );
  assert.equal(interpretationRequest.store, false);
});
