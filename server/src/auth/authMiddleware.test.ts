import assert from "node:assert/strict";
import express, { type ErrorRequestHandler } from "express";
import type { AddressInfo } from "node:net";
import test from "node:test";
import type { ServerConfig } from "../config.js";
import { signAccessToken } from "./tokenUtils.js";
import { isAuthenticatedRequest, requireAuth } from "./authMiddleware.js";

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

test("a validly signed token is rejected immediately when its user no longer exists", async () => {
  const app = express();
  app.get(
    "/protected",
    requireAuth(config, async () => null),
    (request, response) => {
      response.json({ authenticated: isAuthenticatedRequest(request) });
    }
  );
  const errorHandler: ErrorRequestHandler = (error, _request, response, _next) => {
    const statusCode = error instanceof Error && "statusCode" in error
      ? Number(error.statusCode)
      : 500;
    const code = error instanceof Error && "code" in error ? String(error.code) : "INTERNAL_SERVER_ERROR";
    response.status(statusCode).json({ code });
  };
  app.use(errorHandler);
  const server = app.listen(0, "127.0.0.1");

  try {
    await new Promise<void>((resolve, reject) => {
      server.once("listening", resolve);
      server.once("error", reject);
    });
    const address = server.address() as AddressInfo;
    const token = signAccessToken(config, {
      sub: "77777777-7777-4777-8777-777777777777",
      email: "deleted@example.com"
    });
    const response = await fetch(`http://127.0.0.1:${address.port}/protected`, {
      headers: { Authorization: `Bearer ${token}` }
    });

    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { code: "UNAUTHORIZED" });
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
});
