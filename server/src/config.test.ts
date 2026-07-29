import assert from "node:assert/strict";
import test from "node:test";
import type { ServerConfig } from "./config.js";
import { isProductionLikeEnv, validateDeploymentConfig } from "./config.js";

const baseConfig: ServerConfig = {
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
  emailVerificationBaseURL: "https://bphealth-api-staging.onrender.com/auth/verify-email"
};

test("deployment config validation is enabled for staging and production", () => {
  assert.equal(isProductionLikeEnv({ BPHEALTH_ENV: "staging" }), true);
  assert.equal(isProductionLikeEnv({ BPHEALTH_ENV: "production" }), true);
  assert.equal(isProductionLikeEnv({ NODE_ENV: "production" }), true);
  assert.equal(isProductionLikeEnv({ NODE_ENV: "development" }), false);
});

test("staging deployment config rejects development secrets and local URLs", () => {
  assert.throws(
    () => validateDeploymentConfig({
      ...baseConfig,
      accessTokenSecret: "dev-only-change-me-access-token-secret"
    }, {
      BPHEALTH_ENV: "staging",
      DATABASE_URL: "postgresql://user:password@db.example.com:5432/bphealth_staging"
    }),
    /ACCESS_TOKEN_SECRET/
  );

  assert.throws(
    () => validateDeploymentConfig(baseConfig, {
      BPHEALTH_ENV: "staging",
      DATABASE_URL: "postgresql://user:password@localhost:5432/bphealth_staging"
    }),
    /DATABASE_URL/
  );

  assert.throws(
    () => validateDeploymentConfig({
      ...baseConfig,
      emailVerificationBaseURL: "http://localhost:3100/auth/verify-email"
    }, {
      BPHEALTH_ENV: "staging",
      DATABASE_URL: "postgresql://user:password@db.example.com:5432/bphealth_staging"
    }),
    /EMAIL_VERIFICATION_BASE_URL/
  );
});

test("staging deployment config accepts production-like required values", () => {
  assert.doesNotThrow(() => validateDeploymentConfig(baseConfig, {
    BPHEALTH_ENV: "staging",
    DATABASE_URL: "postgresql://user:password@db.example.com:5432/bphealth_staging"
  }));
});
