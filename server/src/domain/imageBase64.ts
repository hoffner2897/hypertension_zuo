import { z } from "zod";

export interface NormalizedImageBase64 {
  base64: string;
  mimeType: "image/jpeg" | "image/png" | "image/webp";
}

export const supportedImageBase64Schema = z.string().trim().min(32).max(7_500_000)
  .refine(isSupportedImageBase64, {
    message: "Image must be valid JPEG, PNG, or WebP base64 data."
  });

export function normalizeImageBase64(value: string): NormalizedImageBase64 {
  const match = value.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/is);
  if (match) {
    return {
      mimeType: (match[1] ?? "image/jpeg").toLowerCase() as NormalizedImageBase64["mimeType"],
      base64: (match[2] ?? "").replace(/\s+/g, "")
    };
  }

  return {
    mimeType: "image/jpeg",
    base64: value.replace(/\s+/g, "")
  };
}

function isSupportedImageBase64(value: string): boolean {
  const normalized = normalizeImageBase64(value);
  if (!["image/jpeg", "image/png", "image/webp"].includes(normalized.mimeType)) {
    return false;
  }

  if (!normalized.base64 || normalized.base64.length % 4 !== 0) {
    return false;
  }
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(normalized.base64)) {
    return false;
  }

  const bytes = Buffer.from(normalized.base64, "base64");
  if (normalized.mimeType === "image/jpeg") {
    return bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (normalized.mimeType === "image/png") {
    return bytes.length >= 8
      && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  }
  return bytes.length >= 12
    && bytes.subarray(0, 4).toString("ascii") === "RIFF"
    && bytes.subarray(8, 12).toString("ascii") === "WEBP";
}
