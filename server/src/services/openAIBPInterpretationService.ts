import { fetch, ProxyAgent } from "undici";
import type { BPBaseInterpretation, BPInterpretationInput, BPInterpretationResult } from "../domain/bloodPressureInterpretation.js";
import { normalizeInterpretationResult } from "../domain/bloodPressureInterpretation.js";

interface OpenAIBPInterpretationServiceOptions {
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
}

const interpretationSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    category: {
      type: "string",
      enum: ["normal", "borderline", "high_home", "low", "urgent", "insufficient_data"]
    },
    severity: {
      type: "string",
      enum: ["reassuring", "watch", "repeat", "follow_up", "urgent"]
    },
    title: { type: "string" },
    summary: { type: "string" },
    reasons: {
      type: "array",
      items: { type: "string" }
    },
    personalContextNotes: {
      type: "array",
      items: { type: "string" }
    },
    measurementQualityNotes: {
      type: "array",
      items: { type: "string" }
    },
    nextSteps: {
      type: "array",
      items: { type: "string" }
    },
    safetyNote: { type: "string" },
    disclaimer: { type: "string" }
  },
  required: [
    "category",
    "severity",
    "title",
    "summary",
    "reasons",
    "personalContextNotes",
    "measurementQualityNotes",
    "nextSteps",
    "safetyNote",
    "disclaimer"
  ]
};

export class OpenAIBPInterpretationService {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly proxyURL?: string;

  constructor(options: OpenAIBPInterpretationServiceOptions) {
    this.apiKey = options.apiKey;
    this.model = options.model;
    this.proxyURL = options.proxyURL;
  }

  async interpret(input: BPInterpretationInput, base: BPBaseInterpretation): Promise<BPInterpretationResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 25_000);

    let response: Awaited<ReturnType<typeof fetch>>;
    try {
      response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        signal: controller.signal,
        dispatcher: this.proxyURL ? new ProxyAgent(this.proxyURL) : undefined,
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: this.model,
          input: [
            {
              role: "system",
              content: [
                {
                  type: "input_text",
                  text: systemPrompt
                }
              ]
            },
            {
              role: "user",
              content: [
                {
                  type: "input_text",
                  text: JSON.stringify({
                    input,
                    fixedRuleResult: base
                  })
                }
              ]
            }
          ],
          text: {
            format: {
              type: "json_schema",
              name: "blood_pressure_interpretation",
              strict: true,
              schema: interpretationSchema
            }
          }
        })
      });
    } catch (error) {
      throw new Error(`OpenAI interpretation request failed before receiving a response: ${describeFetchError(error)}`);
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      const details = await response.text();
      throw new Error(`OpenAI interpretation failed: ${response.status} ${details}`);
    }

    const data = (await response.json()) as ResponsesAPIResponse;
    const text = extractOutputText(data);
    const parsed = JSON.parse(text) as unknown;
    return normalizeInterpretationResult(parsed, base);
  }
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

const systemPrompt = `
你是 BPHealth 的血压读数解释模块，面向中国用户。

只输出 JSON，不输出 Markdown。

硬性规则：
- fixedRuleResult.category 和 fixedRuleResult.severity 是规则引擎结果，必须原样返回，不能改。
- 你可以让中文更自然、更简洁，但不能把单次读数诊断为高血压。
- 不要提供诊断、处方、停药、加药或换药建议。
- 不要使用恐吓语气。
- 家庭血压以 135/85 mmHg 作为偏高随访阈值，不能把门诊 140/90 当作主要家庭阈值。
- borderline/high_home/urgent 必须包含测量质量提示：安静休息 5 分钟、袖带合适、坐姿、手臂与心脏同高等。
- urgent 或危险症状时，安全提示必须明确建议立即寻求急诊帮助。

输出字段：
category, severity, title, summary, reasons, personalContextNotes, measurementQualityNotes, nextSteps, safetyNote, disclaimer。

中文风格：
- 平静、支持性、简短。
- 每条列表尽量不超过 32 个汉字。
- 强调“趋势、复测、家庭平均值、咨询医生”，不说“确诊”。
`.trim();
