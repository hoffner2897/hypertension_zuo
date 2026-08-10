import type { NextFunction, Request, Response } from "express";
import type { ServerConfig } from "../config.js";
import { prisma } from "../db/prisma.js";
import { unauthorized } from "../errors.js";
import { verifyAccessToken } from "./tokenUtils.js";

export interface AuthenticatedRequest extends Request {
  auth: {
    userId: string;
    email: string;
  };
}

export type AuthUserLookup = (userId: string) => Promise<{ id: string; email: string } | null>;

export function requireAuth(config: ServerConfig, userLookup: AuthUserLookup = findAuthUser) {
  return async (request: Request, _response: Response, next: NextFunction): Promise<void> => {
    let payload;
    try {
      const header = request.header("authorization");
      const token = parseBearerToken(header);
      payload = verifyAccessToken(config, token);
    } catch {
      next(unauthorized());
      return;
    }

    let user;
    try {
      user = await userLookup(payload.sub);
    } catch (error) {
      next(error);
      return;
    }

    if (!user) {
      next(unauthorized());
      return;
    }

    (request as AuthenticatedRequest).auth = {
      userId: user.id,
      email: user.email
    };

    next();
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

async function findAuthUser(userId: string): Promise<{ id: string; email: string } | null> {
  return prisma.user.findFirst({
    where: { id: userId, deletedAt: null },
    select: { id: true, email: true }
  });
}
