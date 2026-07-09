# Product Scope

## Product Summary
BPHealth is an iOS-first SwiftUI blood pressure companion app. It supports account-based use, lightweight profile setup, offline blood pressure reading capture, local review, sync, and non-diagnostic result guidance.

The product is now planned as a full-stack app, not a local-only MVP.

## Core User Flow
1. User opens the app.
2. App checks local session.
3. If no session exists, user logs in or registers.
4. Registered users can log in before email verification, but are routed to a verify email screen until verified.
5. Verified users must complete a lightweight profile before entering the main app.
6. Main app supports blood pressure reading review, adding readings, confirmation, analysis, history, and sync.

## First Version Goals
- Email/password registration and login.
- Email verification with console-only delivery during development.
- Access token plus refresh token auth.
- Required lightweight profile setup.
- Apple Health read authorization and health context summary.
- Offline reading creation on iOS.
- Sync of local readings to the backend.
- Account deletion.
- Chinese and English localization.
- Blood pressure values in mmHg only.

## First Version Screens
- Login
- Register
- Verify email
- Profile setup
- Main blood pressure home
- Add reading / camera placeholder
- Confirm reading
- Analysis loading
- Result
- Reading history
- Settings / account
- Delete account

## Explicitly Out Of Scope For First Version
- Lifestyle Step 03.
- Apple Health writes.
- Real camera permissions and capture.
- Real OCR in the iOS app.
- Apple Sign In.
- Push notifications.
- Medication tracking.
- Clinician sharing.
- PDF export.
- Apple Watch support.

## Architecture
```text
iOS SwiftUI App
  Auth flow
  Profile setup
  Blood pressure flow
  GRDB local cache and sync queue
  Keychain refresh token storage

Node Express API
  Auth
  Email verification
  Refresh token lifecycle
  Profile
  Blood pressure readings
  Sync
  Account deletion

PostgreSQL
  users
  user_profiles
  refresh_tokens
  email_verification_tokens
  blood_pressure_readings
```

## Localization
The iOS app supports Chinese and English in the first version.

Backend responses should use stable machine-readable error codes rather than user-facing prose. The iOS app owns localized display text.

## Health Communication Principles
- Use "reading", "trend", "suggestion", and "may indicate".
- Avoid "diagnosis", "disease", "hypertension confirmed", or "you are healthy".
- For unusual readings, recommend repeat measurement and professional guidance when appropriate.
- Present results as supportive context, not medical certainty.

## Success Criteria
- A user can register, verify email, complete profile, add a reading offline, and sync it later.
- Account data is user-scoped.
- Account deletion clears server-owned user data and local session/cache.
- Readings use mmHg.
- Chinese and English UI text are supported.
- The iOS app and Node server build after every implementation task.
