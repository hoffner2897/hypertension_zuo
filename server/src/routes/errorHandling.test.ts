import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import test from "node:test";
import { createApp } from "../app.js";
import type { ServerConfig } from "../config.js";

const config: ServerConfig = {
  port: 0,
  recognitionMode: "mock",
  openAIModel: "test-recognition-model",
  openAIActionSuggestionModel: "test-action-model",
  openAIMealAnalysisModel: "test-meal-model",
  bpRecognitionDailyLimit: 30,
  mealAnalysisDailyLimit: 20,
  accessTokenSecret: "test-only-access-token-secret-with-enough-entropy",
  accessTokenTTLSeconds: 900,
  refreshTokenTTLDays: 30,
  emailVerificationTTLHours: 24,
  emailVerificationBaseURL: "http://localhost/auth/verify-email"
};

test("malformed and oversized JSON use stable public error codes", async () => {
  const app = createApp(config);
  const server = app.listen(0, "127.0.0.1");

  try {
    await new Promise<void>((resolve, reject) => {
      server.once("listening", resolve);
      server.once("error", reject);
    });
    const address = server.address() as AddressInfo;
    const url = `http://127.0.0.1:${address.port}/auth/register`;

    const malformed = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{\"email\""
    });
    assert.equal(malformed.status, 400);
    assert.deepEqual(await malformed.json(), {
      code: "BAD_REQUEST",
      message: "Malformed JSON request body."
    });

    const oversized = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ payload: "x".repeat(8 * 1024 * 1024) })
    });
    assert.equal(oversized.status, 413);
    assert.deepEqual(await oversized.json(), {
      code: "PAYLOAD_TOO_LARGE",
      message: "Request body is too large."
    });
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
});
