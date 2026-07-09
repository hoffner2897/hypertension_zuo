# BPHealth Server

Small local backend for the iOS blood pressure companion app.

The iOS app should never store the OpenAI API key. It sends photo data to this backend, and this backend calls OpenAI.

## Setup

```bash
cd server
npm install
cp .env.example .env
npm run db:generate
npm run dev
```

## Database

Start local PostgreSQL with Docker:

```bash
cd server
docker compose up -d
npm run db:migrate -- --name init
```

The development database URL is defined in `.env.example` and should match `docker-compose.yml`.

Use mock mode first:

```env
BP_RECOGNITION_MODE=mock
```

For real OpenAI recognition:

```env
BP_RECOGNITION_MODE=openai
OPENAI_API_KEY=your_api_key_here
OPENAI_MODEL=gpt-5.5
```

The iOS app never receives the API key. It calls the BPHealth backend, and this backend calls OpenAI.

If your VPN is in smart mode and Terminal cannot reach OpenAI directly, start the server with a temporary proxy:

```bash
OPENAI_PROXY_URL=http://127.0.0.1:8118 npm run dev
```

This only affects that terminal process.

## Endpoints

### GET /health

Returns server status.

## Auth Endpoints

Auth responses use a short-lived `accessToken` and a long-lived opaque `refreshToken`.

Development email verification is console-only. When registration or resend verification creates a token, the server logs a `[dev-email]` verification URL.

The local development API uses port `3100` because Docker Desktop may occupy port `3000` on macOS.

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
  "refreshToken": "rfr_..."
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

Profile routes require an access token and verified email.

### GET /profile

Returns the current user's profile, or `null` if it has not been created.

### PUT /profile

Request:

```json
{
  "displayName": "Haoyu",
  "birthYear": 1995,
  "sex": "prefer_not_to_say"
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

### PUT /readings/:id

Updates a user-owned reading.

### DELETE /readings/:id

Soft-deletes a user-owned reading.

### POST /sync/readings

Idempotently syncs offline-created readings by `clientId`.

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
