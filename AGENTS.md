# BPHealth Agent Instructions

## Product
This is an iOS-first SwiftUI app for blood pressure tracking and basic health context.

## MVP Scope
Implement only:
1. Apple Health connection mock flow
2. Synced health data summary mock screen
3. Blood pressure home card
4. Camera upload mock screen
5. Confirm blood pressure reading screen
6. Analysis loading screen
7. Result screen

Do not implement lifestyle Step 03 yet.

## Tech
- SwiftUI
- MVVM
- SwiftData later
- No backend
- No networking
- HealthKit later
- Camera/OCR later

## Coding Rules
- Keep SwiftUI views lightweight.
- Put state in ViewModels.
- Put reusable UI into Core/DesignSystem.
- Do not hard-code business logic inside views.
- Use mock data first.
- The app must build after every task.

## Health Wording
- Do not use diagnosis language.
- Use wording like "reading", "trend", "suggestion", "may indicate".
- Do not say the user has or does not have a disease.
