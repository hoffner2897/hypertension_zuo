import type { NextFunction, Request, Response } from "express";
import type { ServerConfig } from "../config.js";
import { unauthorized } from "../errors.js";
import { verifyAccessToken } from "./tokenUtils.js";

export interface AuthenticatedRequest extends Request {
  auth: {
    userId: string;
    email: string;
  };
}

export function requireAuth(config: ServerConfig) {
  return (request: Request, _response: Response, next: NextFunction): void => {
    try {
      const header = request.header("authorization");
      const token = parseBearerToken(header);
      const payload = verifyAccessToken(config, token);

      (request as AuthenticatedRequest).auth = {
        userId: payload.sub,
        email: payload.email
      };

      next();
    } catch {
      next(unauthorized());
    }
  };
}

export function isAuthenticatedRequest(request: Request): request is AuthenticatedRequest {
  return typeof (request as AuthenticatedRequest).auth?.userId === "string";
}

function parseBearerToken(header: string | undefined): string {
  if (!header?.startsWith("Bearer ")) {
    throw unauthorized();
  }

  const token = header.slice("Bearer ".length).trim();
  if (!token) {
    throw unauthorized();
  }

  return token;
}
