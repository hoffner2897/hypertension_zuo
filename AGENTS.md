# BPHealth Agent Instructions

## Product
BPHealth is an iOS-first SwiftUI app for blood pressure tracking, lightweight health context, offline reading capture, and account-based sync.

The project is no longer MVP-only. Treat it as a full-stack product with an iOS client, a Node API server, and PostgreSQL persistence.

## Product Flow
The intended app launch flow is:
1. Check local session.
2. If no session, show login/register.
3. If logged in but email is not verified, show verify email.
4. If email is verified but profile is incomplete, show profile setup.
5. If profile is complete, show the main app.

Current implementation note:
- Registration currently auto-verifies users on the backend.
- The iOS root router currently routes by profile completion only; `VerifyEmailView` exists but is not yet part of the enforced launch flow.

## Current Product Scope
Implement toward:
- Email/password registration and login.
- Email verification in the first version.
- Short-lived access tokens and long-lived refresh tokens.
- Required lightweight profile setup after email verification.
- Blood pressure reading capture, confirmation, local analysis, history, and sync.
- Offline blood pressure reading creation with later sync.
- Apple Health authorization and read-only health context import.
- Photo selection/camera capture for blood pressure monitor recognition through the backend, with user confirmation before save.
- Account deletion in the first version.
- Chinese and English localization.

## Tech
- iOS: SwiftUI, MVVM.
- Reusable iOS UI: `Core/DesignSystem`.
- iOS local database: GRDB.swift.
- iOS secure token storage: Keychain for refresh token and device id.
- Backend: Node.js, Express, TypeScript.
- ORM: Prisma.
- Database: PostgreSQL.
- Local database runtime: Docker.
- Email delivery in development: console-only verification links.
- Blood pressure unit: mmHg only.

## Deferred Integrations
- Fully on-device OCR.
- Apple Sign In.
- Push notifications.
- Clinician sharing.
- PDF export.
- Medication tracking.

## Coding Rules
- Keep SwiftUI views lightweight.
- Put state and validation in ViewModels or domain helpers.
- Put reusable UI into `Core/DesignSystem`.
- Do not hard-code business logic inside views.
- Keep API and persistence details out of SwiftUI views.
- Backend endpoints should return stable error codes that the iOS app localizes.
- The app and server should build after every implementation task.
- Use Chinese for collaboration unless the user asks otherwise.

## Health Wording
- Do not use diagnosis language.
- Use wording like "reading", "trend", "suggestion", and "may indicate".
- Do not say the user has or does not have a disease.
- Result and analysis copy must be supportive, non-diagnostic, and trend-oriented.
