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

## Recognition And Interpretation Modes

Use mock recognition first:

```env
BP_RECOGNITION_MODE=mock
```

For real OpenAI recognition:

```env
BP_RECOGNITION_MODE=openai
OPENAI_API_KEY=your_api_key_here
OPENAI_MODEL=gpt-5.5
```

`OPENAI_API_KEY` is required when `BP_RECOGNITION_MODE=openai`. If `OPENAI_API_KEY` is present, `/readings/interpretation` also tries OpenAI interpretation after building a local rule-based baseline; if the OpenAI call fails, it falls back to the rule-based result.

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
- Account deletion hard-deletes the user row; related profile, tokens, verification tokens, and readings cascade.

## Endpoints

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
