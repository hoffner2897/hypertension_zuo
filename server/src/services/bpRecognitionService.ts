import type { BPRecognitionResult } from "../domain/bloodPressureRecognition.js";
import type { NormalizedImageBase64 } from "../domain/imageBase64.js";
import type { OpenAIUsageContext } from "./openAIUsageTracking.js";

export interface BPRecognitionService {
  recognize(image: NormalizedImageBase64, usageContext?: OpenAIUsageContext): Promise<BPRecognitionResult>;
}

export class MockBPRecognitionService implements BPRecognitionService {
  async recognize(_image: NormalizedImageBase64): Promise<BPRecognitionResult> {
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
