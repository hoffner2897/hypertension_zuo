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
  minimumSupportedIOSBuild: 0,
  iosUpdateURL: "https://testflight.apple.com/join/TyhR9xzw",
  accessTokenSecret: "test-only-access-token-secret-with-enough-entropy",
  accessTokenTTLSeconds: 900,
  refreshTokenTTLDays: 30,
  emailVerificationTTLHours: 24,
  emailVerificationBaseURL: "http://localhost/auth/verify-email"
};

test("meal record list and image analysis endpoints require authentication", async () => {
  const app = createApp(config);
  const server = app.listen(0, "127.0.0.1");

  try {
    await new Promise<void>((resolve, reject) => {
      server.once("listening", resolve);
      server.once("error", reject);
    });
    const address = server.address() as AddressInfo;
    const baseURL = `http://127.0.0.1:${address.port}/meal-records`;

    const listResponse = await fetch(`${baseURL}?date=2026-07-21`);
    assert.equal(listResponse.status, 401);

    const analyzeResponse = await fetch(`${baseURL}/analyze`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        mealType: "lunch",
        mealDate: "2026-07-21",
        recordedAt: "2026-07-21T12:30:00.000Z",
        timeZone: "Europe/London",
        imageBase64: "data:image/jpeg;base64,/9j/4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/Z"
      })
    });
    assert.equal(analyzeResponse.status, 401);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
});
