# Screen Specification

## Navigation Shape
The MVP should be an iOS-first SwiftUI flow. Prefer `NavigationStack` for the main flow unless a later design requires tabs.

Proposed flow:
1. Health connection
2. Synced health data
3. Blood pressure reading card
4. Camera upload mock
5. Confirm reading
6. Analysis loading
7. Result

The flow should be fully mock-driven and local-only.

## 1. Health Connection Screen

### Purpose
Introduce the mocked Apple Health connection step and let the user continue without real HealthKit authorization.

### Content
- App or feature title focused on blood pressure context.
- Short explanation that Apple Health connection will help summarize health context later.
- Mock connection status.
- Primary action: continue/connect mock.

### States
- Not connected mock state.
- Connected mock state after tapping the action.

### Rules
- Do not request real HealthKit permissions.
- Do not import HealthKit.
- Do not imply actual Apple Health data has been accessed.

## 2. Synced Health Data Screen

### Purpose
Show a mocked summary of synced health context before the user reviews a blood pressure card.

### Content
- Mock sync status.
- Summary rows/cards for basic context, such as latest blood pressure reading, heart rate, and last updated time.
- Primary action to continue.

### States
- Mock synced data available.
- Optional empty mock state if needed for testing.

### Rules
- Use static mock data.
- Do not call Apple Health APIs.
- Do not present mock values as real device data.

## 3. Blood Pressure Reading Card Screen

### Purpose
Provide the home-style blood pressure reading card and entry point into upload/confirmation.

### Content
- Current or latest mock blood pressure reading card.
- Systolic and diastolic values.
- Optional pulse value.
- Reading timestamp.
- Gentle status label such as "Within usual range" or "Needs attention" depending on mock variant.
- Primary action to add or review a reading.

### States
- Normal mock reading.
- Abnormal mock reading.
- No reading mock state, if useful.

### Rules
- Keep business logic out of the view.
- Use a ViewModel to provide display values and variant state.

## 4. Camera Upload Mock Screen

### Purpose
Represent the future camera/OCR step without using camera APIs.

### Content
- Mock upload area or preview placeholder.
- Copy that indicates this is a local mock flow.
- Primary action to use sample image or continue.
- Secondary action to enter manually, if included in the flow.

### States
- No image selected.
- Sample image selected mock state.

### Rules
- Do not request camera permissions.
- Do not use `PhotosUI`, `AVFoundation`, or OCR frameworks yet.
- Do not store image files.

## 5. Confirm Reading Screen

### Purpose
Let the user confirm or adjust a mocked blood pressure reading before analysis.

### Content
- Systolic value.
- Diastolic value.
- Optional pulse value.
- Reading date/time.
- Source label such as "Sample reading" or "Manual confirmation".
- Primary action to analyze.

### States
- Valid reading.
- Invalid input state, if manual editing is implemented.

### Rules
- Validation should live in a ViewModel or model helper.
- Avoid diagnosis wording.
- Keep values local and mock-driven.

## 6. Analysis Loading Screen

### Purpose
Show a brief local-only analysis state before routing to a result variant.

### Content
- Loading indicator.
- Short reassuring copy such as "Reviewing this reading".
- Optional checklist of local mock checks.

### States
- Loading.
- Completed, then navigate to result.

### Rules
- Do not call a server.
- Do not use networking.
- Use a local timer or immediate transition when implemented.

## 7. Result Screen

### Purpose
Present a clear result summary for normal and abnormal reading variants.

### Normal Variant
- Status: "This reading appears within the selected reference range" or similar.
- Show systolic/diastolic/pulse values.
- Suggest tracking trends over time.
- Primary action to return home or save mock reading.

### Abnormal Variant
- Status: "This reading may need attention" or similar.
- Show systolic/diastolic/pulse values.
- Suggest rechecking after a short rest.
- Suggest contacting a qualified health professional when readings remain elevated or symptoms are present.
- Primary action to return home or review reading.

### Rules
- Do not say the user has hypertension.
- Do not say the user does not have a disease.
- Do not provide emergency triage unless a future requirement explicitly adds it.
- Keep result classification logic outside the view.

## Reusable UI Candidates
- Primary button
- Secondary button
- Reading value display
- Status badge
- Summary row
- Screen header
- Loading panel

Place reusable components under `Core/DesignSystem` when implementation begins.
