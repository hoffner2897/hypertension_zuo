# Codex Tasks

## Working Rules
- The project is now a full-stack BPHealth app, not a local-only MVP.
- Use Chinese for collaboration unless the user asks otherwise.
- Keep SwiftUI views lightweight and state-driven.
- Keep business logic in ViewModels, services, or domain helpers.
- Use reusable iOS UI from `Core/DesignSystem`.
- Backend APIs should return stable error codes for iOS localization.
- The iOS app and server must build after every implementation task.
- Health wording must stay non-diagnostic.

## Current Technical Direction
- iOS: SwiftUI, MVVM, GRDB.swift, Keychain.
- Backend: Node.js, Express, TypeScript.
- ORM: Prisma.
- Database: PostgreSQL.
- Local database runtime: Docker.
- Auth: email/password, email verification, access token plus refresh token.
- HealthKit: read-only Apple Health authorization and context summary.
- Development email: console-only verification links.
- Localization: Chinese and English.
- Blood pressure unit: mmHg only.

## Recommended Implementation Order

### Task 01: Update Product Documents
Replace the old MVP-only documents with the full-stack product plan.

Acceptance:
- `AGENTS.md` describes the full-stack direction.
- `docs/PRODUCT_SCOPE.md` describes auth, profile, sync, localization, and account deletion.
- `docs/DATA_MODEL.md` describes backend and local data models.
- `docs/CODEX_TASKS.md` describes the new task order.

### Task 02: Server Foundation
Migrate the server from the current minimal Node HTTP service to Express.

Acceptance:
- Express app structure exists.
- TypeScript build passes.
- `GET /health` still works.
- Existing recognition mock/OpenAI code is preserved or clearly isolated for later.

### Task 03: Docker PostgreSQL And Prisma
Add local PostgreSQL runtime and Prisma schema.

Acceptance:
- Docker Compose starts PostgreSQL.
- Prisma is configured.
- Initial schema includes users, profiles, refresh tokens, email verification tokens, and blood pressure readings.
- Migrations can run locally.

### Task 04: Auth Backend
Implement registration, login, refresh, logout, email verification, resend verification, and account deletion.

Acceptance:
- Passwords are hashed.
- Refresh and verification tokens are stored hashed.
- Access tokens are short-lived.
- Development email verification link/token is printed to console.
- Account deletion removes user-owned profile/readings and revokes sessions.

### Task 05: Profile Backend
Implement profile get/update.

Acceptance:
- Profile is required before entering main app.
- Profile fields are display name, birth year, and sex.
- Profile routes require auth.

### Task 06: Readings Backend
Implement blood pressure readings and sync endpoints.

Acceptance:
- Readings are scoped to the authenticated user.
- `client_id` makes offline sync idempotent.
- Unit is mmHg only.
- Result wording remains non-diagnostic.

### Task 07: iOS Auth Flow
Add login, register, verify email, and session state.

Acceptance:
- App launch routes by session, email verification, and profile state.
- Refresh token is stored in Keychain.
- Backend error codes are localized in Chinese and English.

### Task 08: iOS Profile Setup
Add required profile setup.

Acceptance:
- Verified users without a completed profile cannot enter the main app.
- Profile fields are display name, birth year, and sex.
- Text is localized.

### Task 09: iOS GRDB Local Store
Add GRDB-backed local cache and sync queue.

Acceptance:
- Readings can be created offline.
- Local readings have client ids and sync states.
- Local cache can be cleared on logout/account deletion.

### Task 10: iOS Readings Sync
Wire local readings to backend sync.

Acceptance:
- Offline readings sync when a session and network are available.
- Duplicate uploads are prevented by `client_id`.
- Sync failures are visible in state and retryable.

### Task 11: Localization Pass
Complete Chinese and English UI text for first-version flows.

Acceptance:
- Auth, profile, readings, settings, and errors are localized.
- Backend returns codes, not user-facing long prose.

### Task 12: Build And Test Pass
Run server checks and iOS build/tests.

Acceptance:
- Server TypeScript check passes.
- iOS app builds.
- Core auth/profile/reading validation has focused tests.

## Deferred Tasks
- Lifestyle Step 03.
- Apple Health writes.
- Real camera capture.
- Real OCR in iOS.
- Apple Sign In.
- Push notifications.
- Medication tracking.
- Clinician sharing.
- PDF export.
- Apple Watch support.
