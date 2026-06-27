# Data Model

## Current Project State
The generated Xcode template currently contains a placeholder SwiftData model named `Item` with a `timestamp`.

For the MVP, implementation should use mock data first. Do not introduce real persistence unless a later task explicitly asks for SwiftData work.

## Future Domain Models

### BloodPressureReading
Represents one blood pressure reading.

Suggested fields:
- `id`: stable identifier
- `systolic`: integer
- `diastolic`: integer
- `pulse`: optional integer
- `measuredAt`: date
- `source`: reading source
- `note`: optional string
- `createdAt`: date

Suggested source values:
- `manual`
- `mockCameraUpload`
- `appleHealthMock`
- `appleHealth`

For the MVP, only `manual`, `mockCameraUpload`, and `appleHealthMock` should be used.

### BloodPressureResult
Represents the local interpretation shown on the result screen.

Suggested fields:
- `reading`: `BloodPressureReading`
- `variant`: normal or abnormal
- `title`: display title
- `summary`: display summary
- `suggestions`: list of non-diagnostic suggestions

### HealthSummary
Represents mocked synced health context.

Suggested fields:
- `connectionStatus`: not connected or connected
- `lastSyncedAt`: optional date
- `latestBloodPressure`: optional `BloodPressureReading`
- `restingHeartRate`: optional integer
- `dataSourceLabel`: string

## MVP State Strategy
- Start with mock structs and ViewModels.
- Keep screen state in ViewModels.
- Avoid storing business rules in SwiftUI views.
- Keep all sample values local.
- Avoid SwiftData migrations until the domain model is stable.

## Suggested ViewModels
- `HealthConnectionViewModel`
- `SyncedHealthDataViewModel`
- `BloodPressureHomeViewModel`
- `CameraUploadMockViewModel`
- `ConfirmReadingViewModel`
- `AnalysisLoadingViewModel`
- `ResultViewModel`

## Reading Classification
The MVP may use simple local classification for result variants, but the wording must stay non-diagnostic.

Suggested output variants:
- `normal`
- `abnormal`

The exact thresholds should be isolated in a helper or ViewModel so they can be reviewed later. Views should receive display-ready state.

## SwiftData Later
When persistence is introduced:
- Replace the placeholder `Item` model with domain-specific models.
- Add migration planning before shipping builds with real user data.
- Keep SwiftData models small and focused.
- Avoid mixing persistence annotations directly into UI-specific display models.

## Privacy And Safety
- Do not send readings to a server.
- Do not add analytics or telemetry in the MVP.
- Do not store camera images in the MVP.
- Treat blood pressure values as sensitive health data even while local-only.
