import type { Request } from "express";

export type AppLocale = "zh-Hans" | "en";

export function requestLocale(request: Request): AppLocale {
  const value = request.header("accept-language")?.trim().toLowerCase() ?? "";
  return value.startsWith("en") ? "en" : "zh-Hans";
}

export function isEnglish(locale: AppLocale | undefined): boolean {
  return locale === "en";
}
