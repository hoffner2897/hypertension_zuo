# BPHealth / Hypertension

BPHealth is an iOS-first SwiftUI app for blood pressure tracking, Apple Health context import, account login, offline reading capture, photo-based reading recognition, and backend sync.

This repository contains two parts:

- `hypertension/`: iOS SwiftUI app.
- `server/`: Node.js + Express + TypeScript API server with PostgreSQL via Prisma.

## Current State

The app is now wired as a full-stack product rather than a local-only MVP.

- iOS has login/register, session refresh, profile setup, HealthKit summary views, photo/manual reading entry, GRDB-backed offline reading storage, remote reading sync, and account settings.
- The iOS API client currently points at staging: `https://bphealth-api-staging.onrender.com`.
- Backend has auth, profile, reading CRUD, reading sync, BP photo recognition, and BP interpretation endpoints.
- Email verification routes and UI exist, but the current backend auto-verifies new registrations and the iOS root router does not yet block unverified users.
- The current app signing settings use bundle id `com.hypertensionapp.hypertension1`, development team `UN2RC766TK`, and app deployment target `iOS 17.6`.

## What To Install

### iOS

- macOS with Xcode 26 or newer.
- An Apple Developer team if you want to run on a physical iPhone with HealthKit and camera access.
- Local Swift package dependency: `external/GRDB.swift`.

The repo ignores `external/`, so a teammate needs to provide or restore `external/GRDB.swift` before opening the Xcode project. The Xcode project currently references it as a local Swift package.

Current local dependency source:

```bash
mkdir -p external
git clone https://github.com/groue/GRDB.swift.git external/GRDB.swift
```

### Backend

- Node.js 20 or newer.
- npm.
- Docker Desktop, for local PostgreSQL.

Node does not use a Python-style `requirements.txt`. The equivalent files are:

- `server/package.json`: direct dependencies and scripts.
- `server/package-lock.json`: exact dependency versions.

After cloning, `npm install` recreates `server/node_modules/`.

## Backend Setup

```bash
cd server
npm install
cp .env.example .env
docker compose up -d
npm run db:generate
npm run db:migrate
npm run dev
```

The local API should then be available at:

```text
http://localhost:3100/health
```

Expected response:

```json
{
  "ok": true,
  "service": "bphealth-server",
  "recognitionMode": "mock"
}
```

## Environment Variables

For local development, start from `server/.env.example`.

Important values:

- `PORT`: local server port. The local development default is usually `3100` via `.env.example`; code fallback is `3000` if no env file is present.
- `DATABASE_URL`: local PostgreSQL connection string.
- `ACCESS_TOKEN_SECRET`: use a strong random value outside local-only testing.
- `BP_RECOGNITION_MODE`: use `mock` for no-cost local testing, or `openai` for real recognition.
- `OPENAI_API_KEY`: required only when `BP_RECOGNITION_MODE=openai`; also enables AI-assisted reading interpretation when present.
- `OPENAI_MODEL`: currently configured as `gpt-5.5` by default.
- `OPENAI_PROXY_URL`: optional proxy for server-side OpenAI calls.

Never commit `server/.env`.

## iOS Setup

1. Confirm `external/GRDB.swift` resolves.
2. Open `hypertension.xcodeproj` in Xcode.
3. Select the `hypertension` scheme.
4. Confirm signing settings for your Apple Developer team and bundle id.
5. Run on an iPhone or simulator.

The iOS API base URL is in:

```text
hypertension/Core/Networking/APIClient.swift
```

Current behavior:

- All iOS builds use `https://bphealth-api-staging.onrender.com`.
- To test against local backend, temporarily change `APIClient.shared.baseURL` in `APIClient.swift` to `http://localhost:3100` for simulator, or to your Mac LAN IP for a physical iPhone.

## Apple Health And Camera Notes

HealthKit data can only be tested meaningfully on a physical iPhone. The app reads:

- Age / birth year
- Sex
- Height
- Weight
- Today steps
- Exercise minutes
- Resting heart rate
- Sleep duration

The entitlements include HealthKit plus `health-records` access. If physical-device signing fails, confirm the App ID capabilities in the Apple Developer portal.

The current photo flow supports selecting a photo or using the camera through `UIImagePickerController`, uploads JPEG data to `/recognize-bp`, and always asks the user to confirm or edit the recognized reading before saving.

## Useful Commands

Backend:

```bash
cd server
npm run check
npm run dev
npm run db:migrate
npm run db:studio
```

iOS command-line build:

```bash
xcodebuild -scheme hypertension -destination 'platform=iOS Simulator,name=iPhone 16' build
```

For a connected physical device, replace the destination with that device id.

## Do Not Commit

These are intentionally ignored or should remain local:

- `server/node_modules/`
- `server/.env`
- `server/dist/`
- `server/venv/`
- `server/.idea/`
- `server/bp_image_test/`
- `external/`
- `.codex-xcode-home/`
- `.idea/`
- Xcode `xcuserdata/`
