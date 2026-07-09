import { createHash, randomBytes, randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import type { ServerConfig } from "../config.js";

export interface AccessTokenPayload {
  sub: string;
  email: string;
}

export interface IssuedRefreshToken {
  token: string;
  hash: string;
  expiresAt: Date;
}

export interface IssuedVerificationToken {
  token: string;
  hash: string;
  expiresAt: Date;
}

export function signAccessToken(config: ServerConfig, payload: AccessTokenPayload): string {
  return jwt.sign(payload, config.accessTokenSecret, {
    expiresIn: config.accessTokenTTLSeconds
  });
}

export function verifyAccessToken(config: ServerConfig, token: string): AccessTokenPayload {
  const decoded = jwt.verify(token, config.accessTokenSecret);

  if (!isAccessTokenPayload(decoded)) {
    throw new Error("Invalid access token payload.");
  }

  return decoded;
}

export function issueRefreshToken(config: ServerConfig): IssuedRefreshToken {
  const token = `rfr_${randomToken()}`;
  return {
    token,
    hash: hashToken(token),
    expiresAt: daysFromNow(config.refreshTokenTTLDays)
  };
}

export function issueVerificationToken(config: ServerConfig): IssuedVerificationToken {
  const token = `ver_${randomToken()}`;
  return {
    token,
    hash: hashToken(token),
    expiresAt: hoursFromNow(config.emailVerificationTTLHours)
  };
}

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export function makeDeviceId(): string {
  return randomUUID();
}

function randomToken(): string {
  return randomBytes(32).toString("base64url");
}

function daysFromNow(days: number): Date {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
}

function hoursFromNow(hours: number): Date {
  return new Date(Date.now() + hours * 60 * 60 * 1000);
}

function isAccessTokenPayload(value: unknown): value is AccessTokenPayload {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as AccessTokenPayload).sub === "string" &&
    typeof (value as AccessTokenPayload).email === "string"
  );
}
