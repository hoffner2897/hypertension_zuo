import {
  normalizeImageBase64,
  supportedImageBase64Schema,
  type NormalizedImageBase64
} from "./imageBase64.js";

export interface RecognizeBPRequest {
  image: NormalizedImageBase64;
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

  const parsed = supportedImageBase64Schema.safeParse(body.imageBase64);
  if (!parsed.success) {
    throw new BadRequestError("imageBase64 must be a valid JPEG, PNG, or WebP image.");
  }

  return { image: normalizeImageBase64(parsed.data) };
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
