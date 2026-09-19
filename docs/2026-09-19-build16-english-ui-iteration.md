# Build 16: English UI iteration

## Scope

Address the issues in the nine-page English UI review dated September 19, 2026.

- Use Today's Actions, BP Readings, Action Studio, and Action Adjustment consistently in English page headings and navigation.
- Hide duplicate English subtitles below the same English page heading.
- Localize structured meal-analysis section headings, reading sources, exercise durations, and the adjusted exercise name.
- Give English timeline titles the full card width and allow complete wrapping. Measure rendered card heights so longer text expands the timeline without overlapping adjacent cards or clipping meal timing guidance.
- Allow full multiline lane headings and energy/context choices; use two columns for longer English context choices.
- Reflow reading-history metadata so English source labels have space alongside dates and pulse values.
- Localize offline action-advice fallback text and timeline accessibility labels; allow the advice introduction to wrap fully.

Existing stored readings, exercise identifiers, user-entered names, historical AI content, and health recommendation rules are preserved.

## Version

- iOS: 1.0 (16)
- No backend or database migration changes.

## Verification and release

- English and Simplified Chinese localization resources pass `plutil` validation.
- iPhone 14 Pro / iOS 26.5 simulator: 53 tests passed, 0 failures (52 unit tests and one UI regression covering both languages).
- Visually reviewed English main screens, complete context labels, offline fallback copy, and Chinese timeline layout from the final test attachments.
- Timeline regression verifies that measured card heights preserve spacing for multiple same-time actions.
- Existing validation tests now compare localized messages, so they work in either language.
- Backend TypeScript build passed (`npm run build`).
- Signed Release archive passed using Xcode 27.0.
- Distribution targets: the existing GitHub release branches and the BPHealth public TestFlight group, version 1.0 (16).
