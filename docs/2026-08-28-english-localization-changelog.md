# BPHealth English localization release — 2026-08-28

## Release

- App version: `1.0 (15)`
- Languages: Simplified Chinese and English
- Language switch: Account & Health → Language
- Existing installations keep Simplified Chinese by default; new installations follow the iPhone language until the user makes an explicit choice.

## iOS client

- Added a persistent in-app language preference with immediate UI refresh.
- Localized authentication, onboarding, profile, Apple Health, blood pressure capture and history, Today's Action, action generation, action adjustment, meal analysis, exercise instructions, validation errors, statuses, permissions, and exercise timer notifications.
- Added an English exercise catalog keyed by the existing canonical exercise identifiers so recommendation rules and historical research data remain unchanged.
- Added `Accept-Language` to authenticated and unauthenticated API requests.
- User-entered exercise names and other free text remain unchanged.
- Historical AI results remain in the language in which they were originally generated.

## Backend and AI

- Added request-locale parsing for `Accept-Language` (`zh-Hans` / `en`).
- Blood-pressure interpretation, meal analysis, action advice, and trend suggestions now generate in the requested language.
- Safety categories and thresholds remain rule-owned. In particular, ordinary elevated readings do not trigger repeat-measurement guidance; repeat guidance begins at the previously approved `160/100 mmHg` boundary unless symptoms require urgent action.
- Meal analyses now store `analysisLocale` for newly generated records. Existing records remain valid and retain their original text.
- Added Prisma migration `20260828120000_add_meal_analysis_locale`.

## Verification

- English and Simplified Chinese localization resources pass `plutil` validation.
- iOS Debug simulator build passed on an iPhone 14 Pro-sized simulator.
- Both English and Simplified Chinese launch screens were run and visually checked.
- Backend TypeScript build passed.
- Backend tests: 49 total, 47 passed, 2 environment-dependent PostgreSQL integration tests skipped, 0 failed.
