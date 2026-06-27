# Product Scope

## Product Summary
BPHealth is an iOS-first SwiftUI blood pressure companion app. The MVP helps a user connect a mocked Apple Health flow, review mocked synced context, capture or confirm a blood pressure reading, wait through a local analysis state, and see a result screen with normal and abnormal variants.

The MVP is local-only. It must not include backend services, networking, HealthKit integration, camera capture, or OCR implementation.

## MVP Goals
- Establish the core screen flow for a blood pressure companion app.
- Use mock data to validate the product experience before platform integrations.
- Keep the code structure ready for MVVM, reusable UI, and future SwiftData.
- Use careful health wording that supports user understanding without diagnosis claims.

## MVP Screens
1. Health connection screen
2. Synced health data screen
3. Blood pressure reading card screen
4. Camera upload mock screen
5. Confirm reading screen
6. Analysis loading screen
7. Result screen with normal and abnormal variants

## Explicitly Out Of Scope
- Lifestyle Step 03
- Real HealthKit authorization
- Real Apple Health reads or writes
- Camera access
- OCR or image recognition
- Networking
- Authentication
- Backend sync
- Push notifications
- Medication tracking
- Clinician sharing
- PDF export
- Apple Watch support
- Charts beyond static/mock summary content

## Local-Only Assumptions
- All data is mock data or in-memory state for now.
- Any persistence should be deferred unless a task explicitly introduces SwiftData.
- The app should remain usable offline.
- Mock flows should be clearly structured so real integrations can replace them later.

## Health Communication Principles
- Use "reading", "trend", "suggestion", and "may indicate".
- Avoid "diagnosis", "disease", "hypertension confirmed", or "you are healthy".
- For abnormal readings, recommend repeat measurement and professional guidance when appropriate.
- Present results as supportive context, not medical certainty.

## MVP Success Criteria
- A user can move through the complete mocked flow.
- The normal and abnormal result variants are visually and textually distinct.
- No screen requires network, HealthKit, camera, OCR, or real permissions.
- The app builds after every implementation task.
- The code organization makes future HealthKit, camera, OCR, and SwiftData work straightforward.
