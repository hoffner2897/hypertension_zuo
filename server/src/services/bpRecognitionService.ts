import type { BPRecognitionResult } from "../domain/bloodPressureRecognition.js";

export interface BPRecognitionService {
  recognize(imageBase64: string): Promise<BPRecognitionResult>;
}

export class MockBPRecognitionService implements BPRecognitionService {
  async recognize(_imageBase64: string): Promise<BPRecognitionResult> {
    await new Promise((resolve) => setTimeout(resolve, 250));

    return {
      systolic: 128,
      diastolic: 82,
      pulse: 72,
      confidence: 0.86,
      needsManualReview: false,
      notes: "Mock recognition result. Confirm before saving."
    };
  }
}
