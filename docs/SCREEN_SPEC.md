# Screen Specification

## Navigation Shape
BPHealth is an iOS-first SwiftUI app. Use a root session state to choose the launch destination, then use `NavigationStack` inside each major flow.

Target launch flow:
1. Checking session
2. Login / register
3. Verify email
4. Profile setup
5. Main app

Current implementation:
- `AppState` checks refresh-token session.
- It currently routes to signed out, profile setup, or main app.
- `VerifyEmailView` exists, but the root route state does not yet include a verify-email gate.

Main app flow:
1. Blood pressure home
2. Add reading / photo recognition
3. Confirm reading
4. Analysis loading
5. Result
6. History
7. Settings / account

## 1. Login Screen

### Purpose
Let an existing user sign in with email and password.

### Content
- Email field.
- Password field.
- Primary action: log in.
- Secondary action: create account.
- Error state from localized backend error codes.

### Rules
- Do not put auth validation directly in the view.
- Do not display raw backend errors.
- Store refresh token in Keychain after successful login.

## 2. Register Screen

### Purpose
Let a new user create an account.

### Content
- Email field.
- Password field.
- Confirm password field.
- Primary action: create account.
- Link back to login.

### Rules
- Backend creates the user and prints a verification link/token in development.
- User may log in before verification, but cannot enter the main app until verified.

## 3. Verify Email Screen

### Purpose
Block main app access until email verification is complete.

### Content
- Email verification status.
- Primary action: check verification status.
- Secondary action: resend verification.
- Development-friendly text can mention checking the server console when running locally.

### Rules
- Keep messaging neutral and localized.
- Do not expose raw tokens in production UI.
- Current UI accepts a development token manually and can resend verification. This is suitable for console-only development email but should be replaced or hidden for production.

## 4. Profile Setup Screen

### Purpose
Collect the required lightweight profile before main app entry.

### Content
- Display name.
- Birth year.
- Sex picker:
  - female
  - male
  - other
  - prefer not to say
- Primary action: continue.

### Rules
- Profile is required.
- Do not ask for diagnosis, disease history, or medication details in the first version.
- Field labels and validation messages must be localized.
- Current setup screen collects display name, birth year, and sex. HealthKit context is handled separately and persisted as optional profile fields.

## 5. Blood Pressure Home Screen

### Purpose
Provide the main blood pressure overview and entry points.

### Content
- Latest reading card.
- Sync state if there are pending or failed offline readings.
- Entry action to add a reading.
- Entry action to view history.
- Settings/account access.

### States
- No readings.
- Latest synced reading.
- Pending offline reading.
- Sync failed.

### Rules
- Keep display logic in a ViewModel.
- Use mmHg only.
- Use non-diagnostic labels such as "within selected range" or "may need attention".

## 6. Add Reading / Photo Recognition Screen

### Purpose
Allow manual reading entry and support blood pressure monitor photo recognition.

### Content
- Manual entry action.
- Photo selection action.
- Camera capture action when camera is available.
- Recognition action that sends compressed JPEG data to the backend.
- Recognition confidence/notes when a result is returned.
- Clear path to manual input when recognition fails or the user prefers manual entry.

### Rules
- Do not save recognized values directly. Route to confirmation first.
- Do not put the OpenAI API key in the iOS app.
- The current implementation uses `PhotosUI` for library selection and `UIImagePickerController` for camera capture.
- Recognition is server-side through `/recognize-bp`; fully on-device OCR remains deferred.

## 7. Confirm Reading Screen

### Purpose
Let the user confirm or adjust a blood pressure reading before saving/analyzing.

### Content
- Systolic value.
- Diastolic value.
- Optional pulse value.
- Measured date/time.
- Source label.
- Note field, optional.
- Primary action to save/analyze.

### States
- Valid reading.
- Invalid input.
- Offline save.
- Sync pending.

### Rules
- Validation lives in a ViewModel or model helper.
- Values are saved locally first so offline entry works.

## 8. Analysis Loading Screen

### Purpose
Show a brief local analysis state before routing to a result variant.

### Content
- Loading indicator.
- Short reassuring copy such as "Reviewing this reading".
- Optional checklist of local checks.

### Rules
- Do not present analysis as diagnosis.
- Current app asks `/readings/interpretation` for guidance and falls back to local rule-based analysis if the request fails.

## 9. Result Screen

### Purpose
Present a clear result summary for the reading.

### Within Selected Range Variant
- Status: "This reading appears within the selected reference range" or similar.
- Show systolic/diastolic/pulse values.
- Suggest tracking trends over time.
- Primary action to return home.

### May Need Attention Variant
- Status: "This reading may need attention" or similar.
- Show systolic/diastolic/pulse values.
- Suggest rechecking after a short rest.
- Suggest contacting a qualified health professional when readings remain elevated or symptoms are present.
- Primary action to return home or review reading.

### Rules
- Do not say the user has hypertension.
- Do not say the user does not have a disease.
- Keep classification logic outside the view.

## 10. History Screen

### Purpose
Let users review saved and pending readings.

### Content
- Reading list.
- Date/time.
- Systolic/diastolic/pulse.
- Sync state for offline entries.
- Empty state.

### Rules
- Readings are user-scoped.
- Pending sync and failed sync states should be visible.

## 11. Settings / Account Screen

### Purpose
Give access to profile, session, language, and account actions.

### Content
- Profile summary.
- Language setting, if not fully driven by system locale.
- Log out.
- Delete account.

### Rules
- Logout clears local session and sensitive cache.
- Delete account requires deliberate confirmation.

## 12. Delete Account Screen

### Purpose
Let the user permanently delete their account and data.

### Content
- Clear explanation that account-owned server data and local cache will be removed.
- Password confirmation.
- Destructive delete action.
- Cancel action.

### Rules
- Backend verifies password before deletion.
- Delete account revokes sessions.
- iOS clears Keychain and GRDB local cache after success.
- The same email may be used again after deletion.

## Reusable UI Candidates
- Primary button.
- Secondary button.
- Destructive button.
- Reading value display.
- Status badge.
- Summary row.
- Screen header.
- Loading panel.
- Form field.
- Error banner.

Place reusable components under `Core/DesignSystem`.
