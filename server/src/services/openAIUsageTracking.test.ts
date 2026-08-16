import assert from "node:assert/strict";
import test from "node:test";
import { openAIErrorCode, parseOpenAIResponseUsage } from "./openAIUsageTracking.js";

test("OpenAI response usage parser captures billed and cached tokens", () => {
  assert.deepEqual(
    parseOpenAIResponseUsage({
      input_tokens: 1_200,
      input_tokens_details: { cached_tokens: 800 },
      output_tokens: 320,
      output_tokens_details: { reasoning_tokens: 120 }
    }),
    {
      inputTokens: 1_200,
      cachedInputTokens: 800,
      outputTokens: 320,
      reasoningTokens: 120
    }
  );
});

test("OpenAI response usage parser safely normalizes missing or invalid values", () => {
  assert.deepEqual(parseOpenAIResponseUsage({ input_tokens: -2, output_tokens: "20" }), {
    inputTokens: 0,
    cachedInputTokens: 0,
    outputTokens: 0,
    reasoningTokens: 0
  });
});

test("OpenAI errors are reduced to stable non-sensitive cost diagnostics", () => {
  assert.equal(openAIErrorCode(new Error("429 credit_balance_exhausted")), "credit_balance_exhausted");
  assert.equal(openAIErrorCode(new Error("OpenAI request failed with status 503")), "openai_503");
  assert.equal(openAIErrorCode(new Error("socket closed")), "openai_request_failed");
});
