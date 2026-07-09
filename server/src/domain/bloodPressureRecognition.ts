export interface RecognizeBPRequest {
  imageBase64: string;
}

export interface BPRecognitionResult {
  systolic: number | null;
  diastolic: number | null;
  pulse: number | null;
  confidence: number;
  needsManualReview: boolean;
  notes: string;
}

export function parseRecognizeBPRequest(body: unknown): RecognizeBPRequest {
  if (!isObject(body) || typeof body.imageBase64 !== "string") {
    throw new BadRequestError("imageBase64 is required.");
  }

  const imageBase64 = normalizeBase64Image(body.imageBase64);
  if (imageBase64.length < 32) {
    throw new BadRequestError("imageBase64 is too short.");
  }

  return { imageBase64 };
}

export function normalizeRecognitionResult(result: unknown): BPRecognitionResult {
  if (!isObject(result)) {
    throw new Error("Recognition result must be an object.");
  }

  return {
    systolic: nullableInteger(result.systolic),
    diastolic: nullableInteger(result.diastolic),
    pulse: nullableInteger(result.pulse),
    confidence: boundedConfidence(result.confidence),
    needsManualReview: typeof result.needsManualReview === "boolean" ? result.needsManualReview : true,
    notes: typeof result.notes === "string" ? result.notes : "请确认识别结果。"
  };
}

export class BadRequestError extends Error {
  statusCode = 400;
}

function normalizeBase64Image(value: string): string {
  return value.replace(/^data:image\/[a-zA-Z0-9.+-]+;base64,/, "").trim();
}

function nullableInteger(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value !== "number" || !Number.isInteger(value)) {
    return null;
  }

  return value;
}

function boundedConfidence(value: unknown): number {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return 0;
  }

  return Math.max(0, Math.min(1, value));
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
