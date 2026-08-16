# BPHealth Server

Node.js + Express + TypeScript backend for BPHealth.

The iOS app should never store the OpenAI API key. Photo recognition and AI-assisted interpretation run through this backend.

## Setup

```bash
cd server
npm install
cp .env.example .env
docker compose up -d
npm run db:generate
npm run db:migrate
npm run dev
```

The local development API normally uses port `3100` from `.env.example`, because Docker Desktop may occupy port `3000` on macOS. If no env file is present, the code fallback is `3000`.

## Database

Start local PostgreSQL with Docker:

```bash
cd server
docker compose up -d
npm run db:migrate
```

The development database URL is defined in `.env.example` and should match `docker-compose.yml`.

## Verification

Run the deterministic unit and route tests:

```bash
npm run check
npm run build
npm test
```

The full local E2E test requires a migrated PostgreSQL database whose database name contains `e2e`. It uses the public registration/login endpoints with a unique email and password, then cleans up the created accounts:

```bash
DATABASE_URL=postgresql://user:password@127.0.0.1:5432/bphealth_e2e npm run db:deploy
RUN_BPHEALTH_E2E=1 DATABASE_URL=postgresql://user:password@127.0.0.1:5432/bphealth_e2e npm run test:e2e
```

The staging smoke test is intentionally gated because it creates one unique test account and deletes it through `DELETE /auth/account` in a `finally` block:

```bash
RUN_BPHEALTH_STAGING_E2E=1 \
BPHEALTH_STAGING_URL=https://bphealth-api-staging.onrender.com \
npm run test:staging
```

## Staging

Use staging for TestFlight builds before production users exist. It should use hosted PostgreSQL and production-like secrets, but it can keep `BP_RECOGNITION_MODE=mock` while you are only testing the app flow.

Start from `server/.env.staging.example` and set these values in Render or your hosting provider:

- `BPHEALTH_ENV=staging`
- `NODE_ENV=production`
- `DATABASE_URL`: hosted staging PostgreSQL, not local Docker.
- `ACCESS_TOKEN_SECRET`: strong random value, for example from `openssl rand -base64 48`.
- `EMAIL_VERIFICATION_BASE_URL`: public HTTPS staging URL.
- `BP_RECOGNITION_MODE`: `mock` for flow testing, `openai` for real image recognition.
- `OPENAI_API_KEY`: required only when `BP_RECOGNITION_MODE=openai`.
- `MINIMUM_SUPPORTED_IOS_BUILD`: minimum accepted iOS build number. Keep `0` until the target TestFlight build is available.
- `IOS_UPDATE_URL`: public HTTPS TestFlight update link returned with `UPDATE_REQUIRED`.

Before or after deployment, validate the environment:

```bash
npm run check:staging-env
```

Deploy database migrations with the production-safe Prisma command:

```bash
npm run db:deploy
```

The service should start with:

```bash
npm run build
npm run start:staging
```

Confirm the deployed API:

```bash
curl https://bphealth-api-staging.onrender.com/health
RUN_BPHEALTH_STAGING_E2E=1 \
BPHEALTH_STAGING_URL=https://bphealth-api-staging.onrender.com \
npm run test:staging
```

## Recognition And Interpretation Modes

Use mock recognition first:

```env
BP_RECOGNITION_MODE=mock
```

For real OpenAI recognition:

```env
BP_RECOGNITION_MODE=openai
OPENAI_API_KEY=your_api_key_here
OPENAI_MODEL=gpt-5.6-terra
OPENAI_ACTION_SUGGESTION_MODEL=gpt-5.6-terra
OPENAI_MEAL_ANALYSIS_MODEL=gpt-5.6-terra
```

`OPENAI_API_KEY` is required when `BP_RECOGNITION_MODE=openai`. If `OPENAI_API_KEY` is present, `/readings/interpretation` also tries OpenAI interpretation after building a local rule-based baseline; if the OpenAI call fails, it falls back to the rule-based result.

`/recognize-bp` requires an access token and accepts only valid JPEG, PNG, or WebP base64 whose file signature matches its declared MIME type. In `openai` mode, new OpenAI requests are limited by `BP_RECOGNITION_DAILY_LIMIT` (default `8`) per user per UTC day. Identical images from the same user are deduplicated for 10 minutes; a cache hit does not consume quota or call OpenAI again.

`/action-adjustments/trend-suggestions` uses `OPENAI_ACTION_SUGGESTION_MODEL`. The server always creates evidence-backed candidates first; OpenAI may only select and polish those candidates. OpenAI advice is cached for 24 hours against a fingerprint of the user's current evidence, so screen refreshes do not regenerate unchanged advice. Evidence changes invalidate the cache. When no key is configured or the OpenAI request fails, the endpoint returns the rule-based candidate wording.

`/meal-records/analyze` uses `OPENAI_MEAL_ANALYSIS_MODEL` and requires authentication. The uploaded meal image is sent to OpenAI with `store: false`, is never written to PostgreSQL, and is discarded after the request. PostgreSQL stores only the generated analysis text, similar-meal suggestion, card summary, meal type, date, and timestamps.

Meal analysis is limited by `MEAL_ANALYSIS_DAILY_LIMIT` (default `9`) per user per UTC day. Identical user/meal/date/image requests are deduplicated for 10 minutes without consuming quota. Both image-analysis quotas are persisted in PostgreSQL and use an atomic increment, so limits remain consistent across restarts and multiple server instances. An exhausted quota returns HTTP `429` with code `AI_DAILY_QUOTA_EXCEEDED`.

Every OpenAI request records daily per-user, per-feature, and per-model counts, success/failure totals, token usage, cache hits, and an estimated cost in `ai_cost_daily_usage`. The table stores no image data or prompt/response content. Cost is an operational estimate based on configured model rates; OpenAI billing remains the source of truth.

Every iOS request includes `X-BPHealth-Build`. When `MINIMUM_SUPPORTED_IOS_BUILD` is greater than zero, requests with a missing, malformed, or older build number receive HTTP `426` with code `UPDATE_REQUIRED`, the minimum build, and `IOS_UPDATE_URL`. `/health` remains available for hosting checks. Raise the minimum only after the matching TestFlight build is in `Testing` state.

If your VPN is in smart mode and Terminal cannot reach OpenAI directly, start the server with a temporary proxy:

```bash
OPENAI_PROXY_URL=http://127.0.0.1:8118 npm run dev
```

This only affects that terminal process.

## Current Implementation Notes

- Auth responses use a short-lived `accessToken` and a long-lived opaque `refreshToken`.
- Refresh and verification tokens are stored hashed.
- Registration currently sets `emailVerifiedAt` immediately, so the verification endpoints exist but are not yet part of the enforced happy path.
- Profile and reading routes require auth. Profile routes are not currently blocked by email verification.
- Readings are user-scoped and use `clientId` for idempotent offline sync.
- Blood pressure values are stored in mmHg only.
- Account deletion hard-deletes the user row; related profile, tokens, verification tokens, readings, meal records, AI quota/cost counters, and cached action advice cascade.

## Endpoints

### GET /meal-records?date=YYYY-MM-DD

Requires an access token. Returns the current user's saved breakfast, lunch, and dinner text analyses for that local calendar date.

### POST /meal-records/analyze

Requires an access token. Analyzes and upserts one meal record for the user, date, and meal type.

```json
{
  "mealType": "lunch",
  "mealDate": "2026-07-21",
  "recordedAt": "2026-07-21T12:30:00.000Z",
  "timeZone": "Europe/London",
  "imageBase64": "data:image/jpeg;base64,..."
}
```

The image is transient. The response and database record contain text only.

### POST /recognize-bp

Requires an access token. Accepts one `imageBase64` field containing JPEG, PNG, or WebP data and returns extracted systolic, diastolic, and pulse candidates for user confirmation. The image is not persisted.

### GET /health

Returns server status.

```json
{
  "ok": true,
  "service": "bphealth-server",
  "recognitionMode": "mock"
}
```

## Auth Endpoints

### POST /auth/register

Request:

```json
{
  "email": "user@example.com",
  "password": "password123",
  "deviceId": "optional-stable-device-id"
}
```

### POST /auth/login

Request:

```json
{
  "email": "user@example.com",
  "password": "password123",
  "deviceId": "optional-stable-device-id"
}
```

### POST /auth/refresh

Request:

```json
{
  "refreshToken": "rfr_...",
  "deviceId": "optional-stable-device-id"
}
```

### POST /auth/logout

Request:

```json
{
  "refreshToken": "rfr_..."
}
```

### GET /auth/me

Requires:

```text
Authorization: Bearer <accessToken>
```

### POST /auth/verify-email

Request:

```json
{
  "token": "ver_..."
}
```

### POST /auth/resend-verification

Request:

```json
{
  "email": "user@example.com"
}
```

If the user exists and is unverified, the server logs a `[dev-email]` verification URL.

### DELETE /auth/account

Requires:

```text
Authorization: Bearer <accessToken>
```

Request:

```json
{
  "password": "password123"
}
```

## Profile Endpoints

Profile routes require an access token.

### GET /profile

Returns the current user's profile, or `null` if it has not been created.

### PUT /profile

Request:

```json
{
  "displayName": "Haoyu",
  "birthYear": 1995,
  "sex": "prefer_not_to_say",
  "heightCm": 175.5,
  "weightKg": 70.2,
  "todaySteps": 8200,
  "exerciseMinutes": 35,
  "restingHeartRate": 62,
  "sleepHours": 7.4,
  "healthDataSource": "healthkit",
  "healthDataSyncedAt": "2026-07-15T08:00:00.000Z"
}
```

Allowed `sex` values are `female`, `male`, `other`, and `prefer_not_to_say`.

## Reading Endpoints

Reading routes require an access token. Values are stored in mmHg.

### GET /readings

Optional query params:

```text
limit=50
cursor=2026-07-07T12:00:00.000Z
includeDeleted=false
```

### POST /readings

Request:

```json
{
  "clientId": "8F347C67-903D-4C34-BC6D-5EB6C6AB6935",
  "systolic": 128,
  "diastolic": 82,
  "pulse": 72,
  "measuredAt": "2026-07-07T12:00:00.000Z",
  "source": "manual",
  "note": "After resting"
}
```

Allowed `source` values are `manual`, `camera_mock`, `camera_ocr`, and `health_import`.

### PUT /readings/:id

Updates a user-owned reading.

### DELETE /readings/:id

Soft-deletes a user-owned reading.

### POST /readings/sync

Idempotently syncs offline-created readings by `clientId`.

### POST /sync/readings

Same sync handler as `/readings/sync`; this is the path currently used by the iOS app.

```json
{
  "readings": [
    {
      "clientId": "8F347C67-903D-4C34-BC6D-5EB6C6AB6935",
      "systolic": 128,
      "diastolic": 82,
      "pulse": 72,
      "measuredAt": "2026-07-07T12:00:00.000Z",
      "source": "manual",
      "note": null
    }
  ]
}
```

### POST /readings/interpretation

Returns non-diagnostic reading guidance. The service builds a rule-based interpretation first and optionally asks OpenAI to refine it when `OPENAI_API_KEY` is configured.

Request:

```json
{
  "systolicBp": 128,
  "diastolicBp": 82,
  "bpMonitorPulse": 72,
  "measurementTime": "2026-07-07T12:00:00.000Z",
  "recentBpReadings": [
    {
      "systolicBp": 124,
      "diastolicBp": 80,
      "measurementTime": "2026-07-06T12:00:00.000Z"
    }
  ]
}
```

### POST /recognize-bp

Request:

```json
{
  "imageBase64": "..."
}
```

Response:

```json
{
  "systolic": 128,
  "diastolic": 82,
  "pulse": 72,
  "confidence": 0.86,
  "needsManualReview": false,
  "notes": "Mock recognition result. Confirm before saving."
}
```

## Action Adjustment Endpoints

### POST /action-adjustments/trend-suggestions

Requires an access token. This endpoint generates wording from the request payload; the separate research snapshot endpoint below persists the Today Action state and changes.

## Today Action research history

The iOS client syncs the complete current-day Today Action tree after launch, foreground activation, and every local item change:

```http
POST /research-actions/sync
Authorization: Bearer <access token>
Content-Type: application/json
```

The server stores two complementary datasets:

- `daily_action_snapshots`: one latest full tree per participant and local day, including planned time, status, completion, BP text, meal-analysis text and exercise selection metadata.
- `action_events`: append-only per-card changes (`created`, `updated`, `rescheduled`, `status_changed`, `deleted`) with before/after JSON.

Photographs and image bytes are not accepted by this endpoint. Requests are limited to 40 cards and bounded text fields. Older out-of-order snapshots do not overwrite newer state.

An authenticated participant can retrieve their own final daily snapshots for diagnostics:

```http
GET /research-actions/days?from=2026-08-01&to=2026-08-14
Authorization: Bearer <access token>
```

Researchers should query/export the PostgreSQL tables using a separately controlled database account rather than exposing cross-participant data through the app API.

Request:

```json
{
  "now": "2026-07-21T18:00:00.000Z",
  "timeZone": "Europe/London",
  "todayActions": [
    {
      "id": "11111111-1111-4111-8111-111111111111",
      "type": "exercise",
      "title": "原地踏步",
      "scheduledStartAt": "2026-07-21T15:00:00.000Z",
      "durationMinutes": 20,
      "status": "missed",
      "completedAt": null
    }
  ],
  "recentActions": []
}
```

Allowed action types are `blood_pressure`, `diet`, `exercise`, and `other`. Allowed statuses are `pending`, `in_progress`, `completed`, `skipped`, and `missed`.

Response:

```json
{
  "status": "ready",
  "source": "rule_based",
  "evidenceDays": 1,
  "suggestions": [
    {
      "targetActionId": "11111111-1111-4111-8111-111111111111",
      "kind": "reschedule",
      "message": "今天16:00的“原地踏步”尚未完成，可调整到更方便的时间。",
      "proposedStartTime": null,
      "proposedDurationMinutes": null,
      "proposedExerciseName": null
    }
  ],
  "dataNote": "建议仅基于今天提供的行动完成情况生成。",
  "disclaimer": "行动调整建议仅用于帮助安排日常计划，不替代专业医疗建议。"
}
```

`status` is `ready` or `no_suggestions`; `source` is `openai` or `rule_based`. Completed and skipped actions may contribute evidence but are never returned as adjustment targets. Multi-day language is only generated when matching observations cover at least three distinct days.
