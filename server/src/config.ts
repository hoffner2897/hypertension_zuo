import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

export type RecognitionMode = "mock" | "openai";

export interface ServerConfig {
  port: number;
  recognitionMode: RecognitionMode;
  openAIAPIKey?: string;
  openAIModel: string;
  openAIActionSuggestionModel: string;
  openAIMealAnalysisModel: string;
  openAIProxyURL?: string;
  bpRecognitionDailyLimit: number;
  mealAnalysisDailyLimit: number;
  accessTokenSecret: string;
  accessTokenTTLSeconds: number;
  refreshTokenTTLDays: number;
  emailVerificationTTLHours: number;
  emailVerificationBaseURL: string;
}

export function loadEnvFile(path = resolve(process.cwd(), ".env")): void {
  if (!existsSync(path)) {
    return;
  }

  const lines = readFileSync(path, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex === -1) {
      continue;
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    const rawValue = trimmed.slice(separatorIndex + 1).trim();
    const value = rawValue.replace(/^["']|["']$/g, "");

    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

export function loadConfig(): ServerConfig {
  loadEnvFile();

  const modeInput = process.env.BP_RECOGNITION_MODE ?? "mock";
  const mode: RecognitionMode = modeInput === "openai" ? "openai" : "mock";
  if (modeInput !== "mock" && modeInput !== "openai") {
    throw new Error("BP_RECOGNITION_MODE must be either 'mock' or 'openai'.");
  }

  const config = {
    port: Number(process.env.PORT ?? 3000),
    recognitionMode: mode,
    openAIAPIKey: process.env.OPENAI_API_KEY,
    openAIModel: process.env.OPENAI_MODEL ?? "gpt-5.6-terra",
    openAIActionSuggestionModel: process.env.OPENAI_ACTION_SUGGESTION_MODEL ?? "gpt-5.6-terra",
    openAIMealAnalysisModel: process.env.OPENAI_MEAL_ANALYSIS_MODEL ?? process.env.OPENAI_MODEL ?? "gpt-5.6-terra",
    openAIProxyURL: process.env.OPENAI_PROXY_URL,
    bpRecognitionDailyLimit: positiveIntegerEnv("BP_RECOGNITION_DAILY_LIMIT", 8),
    mealAnalysisDailyLimit: positiveIntegerEnv("MEAL_ANALYSIS_DAILY_LIMIT", 9),
    accessTokenSecret: process.env.ACCESS_TOKEN_SECRET ?? "dev-only-change-me-access-token-secret",
    accessTokenTTLSeconds: Number(process.env.ACCESS_TOKEN_TTL_SECONDS ?? 900),
    refreshTokenTTLDays: Number(process.env.REFRESH_TOKEN_TTL_DAYS ?? 30),
    emailVerificationTTLHours: Number(process.env.EMAIL_VERIFICATION_TTL_HOURS ?? 24),
    emailVerificationBaseURL: process.env.EMAIL_VERIFICATION_BASE_URL ?? "http://localhost:3000/auth/verify-email"
  };

  validateDeploymentConfig(config);
  return config;
}

function positiveIntegerEnv(name: string, fallback: number): number {
  const value = Number(process.env[name] ?? fallback);
  if (!Number.isInteger(value) || value < 1) {
    throw new Error(`${name} must be a positive integer.`);
  }
  return value;
}

export function validateDeploymentConfig(
  config: ServerConfig,
  env: NodeJS.ProcessEnv = process.env
): void {
  if (!isProductionLikeEnv(env)) {
    return;
  }

  if (isPlaceholderSecret(config.accessTokenSecret)) {
    throw new Error("ACCESS_TOKEN_SECRET must be set to a strong non-development value for staging/production.");
  }

  const databaseURL = env.DATABASE_URL;
  if (!databaseURL) {
    throw new Error("DATABASE_URL is required for staging/production.");
  }

  assertNonLocalURL(databaseURL, "DATABASE_URL");
  assertPublicHTTPSURL(config.emailVerificationBaseURL, "EMAIL_VERIFICATION_BASE_URL");

  if (config.recognitionMode === "openai" && isPlaceholderValue(config.openAIAPIKey)) {
    throw new Error("OPENAI_API_KEY is required when BP_RECOGNITION_MODE=openai.");
  }
}

export function isProductionLikeEnv(env: NodeJS.ProcessEnv = process.env): boolean {
  return env.NODE_ENV === "production" || env.BPHEALTH_ENV === "staging" || env.BPHEALTH_ENV === "production";
}

function isPlaceholderSecret(value: string | undefined): boolean {
  if (!value || isPlaceholderValue(value)) {
    return true;
  }

  return value === "dev-only-change-me-access-token-secret" || value.length < 32;
}

function isPlaceholderValue(value: string | undefined): boolean {
  if (!value) {
    return true;
  }

  const normalized = value.toLowerCase();
  return normalized.includes("dev-only")
    || normalized.includes("change-me")
    || normalized.includes("your_")
    || normalized.includes("placeholder");
}

function assertNonLocalURL(value: string, name: string): void {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${name} must be a valid URL for staging/production.`);
  }

  if (["localhost", "127.0.0.1", "::1"].includes(url.hostname)) {
    throw new Error(`${name} must not point at a local database for staging/production.`);
  }
}

function assertPublicHTTPSURL(value: string, name: string): void {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${name} must be a valid URL for staging/production.`);
  }

  if (url.protocol !== "https:") {
    throw new Error(`${name} must use HTTPS for staging/production.`);
  }

  if (["localhost", "127.0.0.1", "::1"].includes(url.hostname)) {
    throw new Error(`${name} must not point at localhost for staging/production.`);
  }
}
