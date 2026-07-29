import { loadConfig } from "./config.js";

process.env.BPHEALTH_ENV = process.env.BPHEALTH_ENV ?? "staging";

const config = loadConfig();

console.log("BPHealth staging environment looks usable.");
console.log(`Recognition mode: ${config.recognitionMode}`);
console.log(`Access token TTL: ${config.accessTokenTTLSeconds}s`);
console.log(`Refresh token TTL: ${config.refreshTokenTTLDays}d`);
console.log(`Email verification URL: ${config.emailVerificationBaseURL}`);

if (config.recognitionMode === "mock") {
  console.warn("BP_RECOGNITION_MODE=mock: TestFlight can test the flow, but photo recognition will not use OpenAI.");
}
