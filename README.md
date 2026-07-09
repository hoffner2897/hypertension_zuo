# BPHealth / Hypertension

BPHealth is an iOS-first SwiftUI app for blood pressure tracking, Apple Health context import, account login, offline reading capture, and backend sync.

This repository contains two parts:

- `hypertension/`: iOS SwiftUI app.
- `server/`: Node.js + Express + TypeScript API server with PostgreSQL via Prisma.

## What To Install

### iOS

- macOS with Xcode 26 or newer.
- An Apple Developer team if you want to run on a physical iPhone with HealthKit.
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

The API should then be available at:

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

- `DATABASE_URL`: local PostgreSQL connection string.
- `ACCESS_TOKEN_SECRET`: use a strong random value outside local-only testing.
- `BP_RECOGNITION_MODE`: use `mock` for no-cost local testing, or `openai` for real recognition.
- `OPENAI_API_KEY`: required only when `BP_RECOGNITION_MODE=openai`.
- `OPENAI_MODEL`: currently configured as `gpt-5.5`.

Never commit `server/.env`.

## iOS Setup

1. Make sure the backend is running.
2. Open `hypertension.xcodeproj` in Xcode.
3. Confirm the local package `external/GRDB.swift` resolves.
4. Select the `hypertension` scheme.
5. Run on an iPhone or simulator.

The iOS API base URL is in:

```text
hypertension/Core/Networking/APIClient.swift
```

Current behavior:

- Simulator uses `http://localhost:3100`.
- Physical iPhone uses the configured LAN IP, currently `http://192.168.1.55:3100`.

If another developer uses a real iPhone, they must change the physical-device URL to their Mac's LAN IP, or later to a production HTTPS API.

## Apple Health Notes

HealthKit data can only be tested meaningfully on a physical iPhone. The app reads:

- Age / birth year
- Sex
- Height
- Weight
- Today steps
- Exercise minutes
- Resting heart rate
- Sleep duration

Manual input is available for missing or incorrect Health data.

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

These are intentionally ignored:

- `server/node_modules/`
- `server/.env`
- `server/dist/`
- `server/venv/`
- `server/.idea/`
- `server/bp_image_test/`
- `external/`
