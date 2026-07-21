# OpenAI Blood Pressure Recognition Plan

## Goal

Use a multimodal model to read numbers from a blood pressure monitor photo, then ask the user to confirm the result before saving.

## Security Rule

Do not put the OpenAI API key in the iOS app.

The iOS app should send the image to our own backend or serverless endpoint. That backend calls the OpenAI API with the secret key and returns structured JSON to the app.

## iOS Flow

1. User takes a photo or selects one from the photo library.
2. App compresses the image into JPEG data.
3. App sends `imageBase64` to the recognition endpoint.
4. Backend returns structured reading data.
5. App opens `BPConfirmReadingView`.
6. User confirms or edits the reading.
7. App saves the confirmed reading locally.

## Endpoint Contract

Request:

```json
{
  "imageBase64": "..."
}
```

Response:

```json
{
  "systolic": 128,
  "diastolic": 82,
  "pulse": 72,
  "confidence": 0.86,
  "needsManualReview": false,
  "notes": "Numbers are clear."
}
```

If the model is uncertain:

```json
{
  "systolic": null,
  "diastolic": null,
  "pulse": null,
  "confidence": 0.3,
  "needsManualReview": true,
  "notes": "Image is blurry. Ask the user to enter the reading manually."
}
```

## OpenAI Prompt Shape

Ask the model to read only visible monitor numbers and return JSON. The model should not infer missing values, provide diagnosis, mention medication, or give clinical advice.

Required fields:

- `systolic`
- `diastolic`
- `pulse`
- `confidence`
- `needsManualReview`
- `notes`

## Current App State

The app now has:

- `BloodPressureRecognitionService`
- `MockBloodPressureRecognitionService`
- `RemoteBloodPressureRecognitionService`
- `BPCameraUploadMockView`
- `BPCameraUploadViewModel`
- `CameraCaptureView`

The default app path now builds a `RemoteBloodPressureRecognitionService` pointed at `/recognize-bp` relative to `APIClient.shared.baseURL`. The current API base URL is staging: `https://bphealth-api-staging.onrender.com`.

The mock recognition service still exists for previews/tests or local substitution, but the normal UI path expects a reachable backend.

## Backend State

The backend supports two recognition modes:

- `mock`: returns deterministic sample values.
- `openai`: calls OpenAI from the server using `OPENAI_API_KEY`.

The backend also exposes `/readings/interpretation`, which builds a local rule-based interpretation and can use OpenAI for refinement when `OPENAI_API_KEY` is configured.
