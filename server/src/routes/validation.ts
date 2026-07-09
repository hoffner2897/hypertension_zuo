import { z } from "zod";
import { badRequest } from "../errors.js";

export function parseBody<T>(schema: z.ZodType<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) {
    throw badRequest("VALIDATION_FAILED", "Request validation failed.");
  }

  return result.data;
}

export function parseQuery<T>(schema: z.ZodType<T>, query: unknown): T {
  const result = schema.safeParse(query);
  if (!result.success) {
    throw badRequest("VALIDATION_FAILED", "Request validation failed.");
  }

  return result.data;
}
