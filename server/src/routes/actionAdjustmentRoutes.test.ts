import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import test from "node:test";
import type { ServerConfig } from "../config.js";
import { createApp } from "../app.js";
import { signAccessToken } from "../auth/tokenUtils.js";

const config: ServerConfig = {
  port: 0,
  recognitionMode: "mock",
  openAIModel: "test-recognition-model",
  openAIActionSuggestionModel: "test-action-model",
  accessTokenSecret: "test-only-access-token-secret-with-enough-entropy",
  accessTokenTTLSeconds: 900,
  refreshTokenTTLDays: 30,
  emailVerificationTTLHours: 24,
  emailVerificationBaseURL: "http://localhost/auth/verify-email"
};

test("trend suggestion endpoint requires auth and returns the public fallback contract", async () => {
  const app = createApp(config);
  const server = app.listen(0, "127.0.0.1");

  try {
    await new Promise<void>((resolve, reject) => {
      server.once("listening", resolve);
      server.once("error", reject);
    });
    const address = server.address() as AddressInfo;
    const url = `http://127.0.0.1:${address.port}/action-adjustments/trend-suggestions`;
    const body = JSON.stringify({
      now: "2026-07-21T18:00:00.000Z",
      timeZone: "Europe/London",
      todayActions: [{
        id: "11111111-1111-4111-8111-111111111111",
        type: "exercise",
        title: "原地踏步",
        scheduledStartAt: "2026-07-21T15:00:00.000Z",
        durationMinutes: 20,
        status: "missed",
        completedAt: null
      }],
      recentActions: []
    });

    const unauthorizedResponse = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body
    });
    assert.equal(unauthorizedResponse.status, 401);

    const accessToken = signAccessToken(config, {
      sub: "33333333-3333-4333-8333-333333333333",
      email: "test@example.com"
    });
    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body
    });
    const payload = await response.json() as Record<string, unknown>;

    assert.equal(response.status, 200);
    assert.equal(payload.status, "ready");
    assert.equal(payload.source, "rule_based");
    assert.equal(payload.evidenceDays, 1);
    assert.equal(Array.isArray(payload.suggestions), true);
    assert.equal(typeof payload.dataNote, "string");
    assert.equal(typeof payload.disclaimer, "string");
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
});
