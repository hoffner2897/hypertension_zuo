# Codex Tasks

## Working Rules
- Do not modify Swift app code unless the current task explicitly asks for implementation.
- Keep the MVP local-only.
- Do not add networking.
- Do not implement HealthKit yet.
- Do not implement camera, photo library, or OCR yet.
- Do not implement lifestyle Step 03 yet.
- The app must build after every implementation task.
- Use Chinese for collaboration unless the user asks otherwise.

## Recommended Implementation Order

### Task 01: Project Structure
Create the initial app folders without changing product behavior.

Suggested folders:
- `App`
- `Features/HealthConnection`
- `Features/SyncedHealthData`
- `Features/BloodPressureHome`
- `Features/CameraUploadMock`
- `Features/ConfirmReading`
- `Features/Analysis`
- `Features/Result`
- `Core/DesignSystem`
- `Core/Models`
- `Core/MockData`

Acceptance:
- App still builds.
- No real HealthKit, camera, OCR, networking, or SwiftData domain migration.

### Task 02: Mock Domain Models
Add local mock structs and enums for blood pressure readings, health summaries, and result variants.

Acceptance:
- Models are independent from SwiftUI views.
- Mock data is centralized.
- No persistence required.

### Task 03: Design System Basics
Create reusable UI components needed by the MVP screens.

Candidates:
- Primary button
- Secondary button
- Status badge
- Reading value display
- Summary row
- Screen header

Acceptance:
- Components are reusable and previewable.
- No nested card-heavy layout.
- Text fits on iPhone-sized screens.

### Task 04: Health Connection Mock Screen
Implement the mocked Apple Health connection screen.

Acceptance:
- No HealthKit import.
- User can continue through the mock flow.
- Copy clearly avoids implying real Apple Health access.

### Task 05: Synced Health Data Mock Screen
Implement the mocked synced health data summary screen.

Acceptance:
- Uses static mock data.
- Shows connection/sync context.
- Provides a clear next action.

### Task 06: Blood Pressure Reading Card Screen
Implement the blood pressure home card screen.

Acceptance:
- Shows latest mock reading.
- Provides normal and abnormal display states where useful.
- Routes to the mock upload or confirmation step.

### Task 07: Camera Upload Mock Screen
Implement the future camera/OCR placeholder screen.

Acceptance:
- No camera permissions.
- No OCR.
- No photo library import.
- User can continue with a sample reading.

### Task 08: Confirm Reading Screen
Implement the confirmation screen for a mock reading.

Acceptance:
- Values are editable only if requested by the task.
- Validation does not live in the view.
- Continue action routes to analysis loading.

### Task 09: Analysis Loading Screen
Implement the local analysis loading screen.

Acceptance:
- No network calls.
- Uses local timer or immediate mock transition.
- Routes to result screen.

### Task 10: Result Screen Variants
Implement normal and abnormal result variants.

Acceptance:
- No diagnosis language.
- Normal and abnormal variants are visually distinct.
- Suggestions are non-diagnostic and user-supportive.

### Task 11: Build And Polish Pass
Run a build and fix any compile issues.

Acceptance:
- App builds.
- No out-of-scope integrations were added.
- Screens remain local-only and mock-driven.

## Deferred Tasks
- Lifestyle Step 03
- Real HealthKit authorization
- Apple Health data reads/writes
- Camera capture
- OCR
- SwiftData persistence
- Trends and charts
- Export or sharing
- Notifications
- Backend sync
