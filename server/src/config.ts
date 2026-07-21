import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

export type RecognitionMode = "mock" | "openai";

export interface ServerConfig {
  port: number;
  recognitionMode: RecognitionMode;
  openAIAPIKey?: string;
  openAIModel: string;
  openAIActionSuggestionModel: string;
  openAIProxyURL?: string;
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

  const mode = process.env.BP_RECOGNITION_MODE ?? "mock";
  if (mode !== "mock" && mode !== "openai") {
    throw new Error("BP_RECOGNITION_MODE must be either 'mock' or 'openai'.");
  }

  return {
    port: Number(process.env.PORT ?? 3000),
    recognitionMode: mode,
    openAIAPIKey: process.env.OPENAI_API_KEY,
    openAIModel: process.env.OPENAI_MODEL ?? "gpt-5.5",
    openAIActionSuggestionModel: process.env.OPENAI_ACTION_SUGGESTION_MODEL ?? "gpt-5.6-sol",
    openAIProxyURL: process.env.OPENAI_PROXY_URL,
    accessTokenSecret: process.env.ACCESS_TOKEN_SECRET ?? "dev-only-change-me-access-token-secret",
    accessTokenTTLSeconds: Number(process.env.ACCESS_TOKEN_TTL_SECONDS ?? 900),
    refreshTokenTTLDays: Number(process.env.REFRESH_TOKEN_TTL_DAYS ?? 30),
    emailVerificationTTLHours: Number(process.env.EMAIL_VERIFICATION_TTL_HOURS ?? 24),
    emailVerificationBaseURL: process.env.EMAIL_VERIFICATION_BASE_URL ?? "http://localhost:3000/auth/verify-email"
  };
}
