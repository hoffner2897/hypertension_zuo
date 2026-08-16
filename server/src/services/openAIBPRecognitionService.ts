import { fetch, ProxyAgent } from "undici";
import type { BPRecognitionResult } from "../domain/bloodPressureRecognition.js";
import { normalizeRecognitionResult } from "../domain/bloodPressureRecognition.js";
import type { BPRecognitionService } from "./bpRecognitionService.js";
import type { NormalizedImageBase64 } from "../domain/imageBase64.js";
import {
  openAIErrorCode,
  parseOpenAIResponseUsage,
  recordOpenAIUsage,
  type OpenAIResponseUsage,
  type OpenAIUsageContext
} from "./openAIUsageTracking.js";

interface OpenAIRecognitionServiceOptions {
  apiKey: string;
  model: string;
  proxyURL?: string;
}

interface ResponsesAPIResponse {
  output_text?: string;
  output?: Array<{
    type?: string;
    content?: Array<{
      type?: string;
      text?: string;
    }>;
  }>;
  usage?: {
    input_tokens?: unknown;
    output_tokens?: unknown;
    input_tokens_details?: { cached_tokens?: unknown };
    output_tokens_details?: { reasoning_tokens?: unknown };
  };
}

const recognitionSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    systolic: {
      anyOf: [{ type: "integer" }, { type: "null" }]
    },
    diastolic: {
      anyOf: [{ type: "integer" }, { type: "null" }]
    },
    pulse: {
      anyOf: [{ type: "integer" }, { type: "null" }]
    },
    confidence: {
      type: "number",
      minimum: 0,
      maximum: 1
    },
    needsManualReview: {
      type: "boolean"
    },
    notes: {
      type: "string"
    }
  },
  required: ["systolic", "diastolic", "pulse", "confidence", "needsManualReview", "notes"]
};

export class OpenAIBPRecognitionService implements BPRecognitionService {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly proxyURL?: string;

  constructor(options: OpenAIRecognitionServiceOptions) {
    this.apiKey = options.apiKey;
    this.model = options.model;
    this.proxyURL = options.proxyURL;
  }

  async recognize(image: NormalizedImageBase64, usageContext?: OpenAIUsageContext): Promise<BPRecognitionResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30_000);
    let usage: OpenAIResponseUsage | undefined;

    try {
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        signal: controller.signal,
        dispatcher: this.proxyURL ? new ProxyAgent(this.proxyURL) : undefined,
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(makeOpenAIBPRecognitionRequestBody(this.model, image))
      });

      if (!response.ok) {
        const details = await response.text();
        throw new Error(`OpenAI recognition failed: ${response.status} ${details}`);
      }

      const data = (await response.json()) as ResponsesAPIResponse;
      usage = parseOpenAIResponseUsage(data.usage);
      const text = extractOutputText(data);
      const parsed = JSON.parse(text) as unknown;
      const result = normalizeRecognitionResult(parsed);
      if (usageContext) {
        await recordOpenAIUsage({ context: usageContext, model: this.model, succeeded: true, usage });
      }
      return result;
    } catch (error) {
      const recordedError = error instanceof Error
        ? error
        : new Error(`OpenAI request failed before receiving a response: ${describeFetchError(error)}`);
      if (usageContext) {
        await recordOpenAIUsage({
          context: usageContext,
          model: this.model,
          succeeded: false,
          usage,
          errorCode: openAIErrorCode(recordedError)
        });
      }
      throw recordedError;
    } finally {
      clearTimeout(timeout);
    }
  }
}

export function makeOpenAIBPRecognitionRequestBody(
  model: string,
  image: NormalizedImageBase64
) {
  return {
    model,
    store: false,
    input: [
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: recognitionPrompt
          },
          {
            type: "input_image",
            detail: "low",
            image_url: `data:${image.mimeType};base64,${image.base64}`
          }
        ]
      }
    ],
    text: {
      format: {
        type: "json_schema",
        name: "blood_pressure_recognition",
        strict: true,
        schema: recognitionSchema
      }
    }
  };
}

function describeFetchError(error: unknown): string {
  if (error instanceof Error) {
    const cause = error.cause instanceof Error ? ` Cause: ${error.cause.message}` : "";
    return `${error.name}: ${error.message}.${cause}`;
  }

  return String(error);
}

function extractOutputText(data: ResponsesAPIResponse): string {
  if (typeof data.output_text === "string" && data.output_text.trim()) {
    return data.output_text;
  }

  for (const item of data.output ?? []) {
    for (const content of item.content ?? []) {
      if (content.type === "output_text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }

  throw new Error("OpenAI response did not include output text.");
}

const recognitionPrompt = `
You are reading a photo of a blood pressure monitor.

Extract only numbers that are clearly visible on the monitor.

Return:
- systolic: the systolic blood pressure number, or null if unclear
- diastolic: the diastolic blood pressure number, or null if unclear
- pulse: pulse or heart rate, or null if unclear
- confidence: a number from 0 to 1
- needsManualReview: true when any value is unclear or inferred
- notes: a short note for the app

Rules:
- Do not infer missing values.
- Do not provide diagnosis.
- Do not mention medication.
- Do not give medical advice.
- If the photo is blurry, cropped, reflective, or ambiguous, return nulls for uncertain values and set needsManualReview to true.
`.trim();
