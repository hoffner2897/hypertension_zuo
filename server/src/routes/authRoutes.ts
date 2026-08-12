import { randomUUID } from "node:crypto";
import { Router } from "express";
import { z } from "zod";
import type { ServerConfig } from "../config.js";
import { prisma } from "../db/prisma.js";
import { badRequest, conflict, forbidden, unauthorized } from "../errors.js";
import { isAuthenticatedRequest, requireAuth } from "../auth/authMiddleware.js";
import type { AuthUserLookup } from "../auth/authMiddleware.js";
import { hashPassword, verifyPassword } from "../auth/passwords.js";
import { parseBody } from "./validation.js";
import {
  hashToken,
  issueRefreshToken,
  issueVerificationToken,
  makeDeviceId,
  signAccessToken
} from "../auth/tokenUtils.js";

const normalizedEmail = z.string().trim().email().transform((value) => value.toLowerCase());
const password = z.string().min(8).max(128);
const optionalDeviceId = z.string().trim().min(1).max(128).optional();

const registerSchema = z.object({
  email: normalizedEmail,
  password,
  deviceId: optionalDeviceId
});

const loginSchema = registerSchema;

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
  deviceId: optionalDeviceId
});

const logoutSchema = z.object({
  refreshToken: z.string().min(1)
});

const verifyEmailSchema = z.object({
  token: z.string().min(1)
});

const resendVerificationSchema = z.object({
  email: normalizedEmail
});

const deleteAccountSchema = z.object({
  password
});

export function createAuthRouter(config: ServerConfig, authUserLookup?: AuthUserLookup): Router {
  const router = Router();

  router.post("/register", async (request, response, next) => {
    try {
      const input = parseBody(registerSchema, request.body);
      const existingUser = await prisma.user.findUnique({
        where: { email: input.email }
      });

      if (existingUser) {
        throw conflict("EMAIL_ALREADY_REGISTERED", "Email is already registered.");
      }

      let createdUser;
      try {
        createdUser = await prisma.user.create({
          data: {
            email: input.email,
            passwordHash: await hashPassword(input.password),
            emailVerifiedAt: new Date()
          },
          include: {
            profile: true
          }
        });
      } catch (error) {
        if (isUniqueConstraintError(error)) {
          throw conflict("EMAIL_ALREADY_REGISTERED", "Email is already registered.");
        }
        throw error;
      }

      const authResponse = await issueAuthResponse(config, createdUser.id, input.deviceId);
      response.status(201).json(authResponse);
    } catch (error) {
      next(error);
    }
  });

  router.post("/login", async (request, response, next) => {
    try {
      const input = parseBody(loginSchema, request.body);
      const user = await prisma.user.findUnique({
        where: { email: input.email },
        include: { profile: true }
      });

      if (user?.deletedAt || !user || !(await verifyPassword(input.password, user.passwordHash))) {
        throw unauthorized("INVALID_CREDENTIALS", "Email or password is incorrect.");
      }

      const authResponse = await issueAuthResponse(config, user.id, input.deviceId);
      response.json(authResponse);
    } catch (error) {
      next(error);
    }
  });

  router.post("/refresh", async (request, response, next) => {
    try {
      const input = parseBody(refreshSchema, request.body);
      const tokenHash = hashToken(input.refreshToken);
      const storedToken = await prisma.refreshToken.findUnique({
        where: { tokenHash },
        include: {
          user: {
            include: { profile: true }
          }
        }
      });

      if (!storedToken || storedToken.user.deletedAt || storedToken.revokedAt || storedToken.expiresAt <= new Date()) {
        throw unauthorized("INVALID_REFRESH_TOKEN", "Refresh token is invalid.");
      }

      const revoked = await prisma.refreshToken.updateMany({
        where: {
          id: storedToken.id,
          revokedAt: null,
          expiresAt: { gt: new Date() }
        },
        data: { revokedAt: new Date() }
      });

      if (revoked.count !== 1) {
        throw unauthorized("INVALID_REFRESH_TOKEN", "Refresh token is invalid.");
      }

      const authResponse = await issueAuthResponse(config, storedToken.user.id, input.deviceId ?? storedToken.deviceId);
      response.json(authResponse);
    } catch (error) {
      next(error);
    }
  });

  router.post("/logout", async (request, response, next) => {
    try {
      const input = parseBody(logoutSchema, request.body);
      await prisma.refreshToken.updateMany({
        where: {
          tokenHash: hashToken(input.refreshToken),
          revokedAt: null
        },
        data: { revokedAt: new Date() }
      });

      response.sendStatus(204);
    } catch (error) {
      next(error);
    }
  });

  router.get("/me", requireAuth(config, authUserLookup), async (request, response, next) => {
    try {
      if (!isAuthenticatedRequest(request)) {
        throw unauthorized();
      }

      const user = await prisma.user.findUnique({
        where: { id: request.auth.userId },
        include: { profile: true }
      });

      if (!user) {
        throw unauthorized();
      }

      response.json({
        user: serializeUser(user)
      });
    } catch (error) {
      next(error);
    }
  });

  router.post("/verify-email", async (request, response, next) => {
    try {
      const input = parseBody(verifyEmailSchema, request.body);
      const tokenHash = hashToken(input.token);
      const verificationToken = await prisma.emailVerificationToken.findUnique({
        where: { tokenHash },
        include: {
          user: { include: { profile: true } }
        }
      });

      if (
        !verificationToken ||
        verificationToken.consumedAt ||
        verificationToken.expiresAt <= new Date()
      ) {
        throw badRequest("INVALID_EMAIL_VERIFICATION_TOKEN", "Email verification token is invalid.");
      }

      const now = new Date();
      const [, user] = await prisma.$transaction([
        prisma.emailVerificationToken.update({
          where: { id: verificationToken.id },
          data: { consumedAt: now }
        }),
        prisma.user.update({
          where: { id: verificationToken.userId },
          data: { emailVerifiedAt: now },
          include: { profile: true }
        })
      ]);

      response.json({
        user: serializeUser(user)
      });
    } catch (error) {
      next(error);
    }
  });

  router.post("/resend-verification", async (request, response, next) => {
    try {
      const input = parseBody(resendVerificationSchema, request.body);
      const user = await prisma.user.findUnique({
        where: { email: input.email }
      });

      if (user && !user.emailVerifiedAt) {
        await createAndLogVerificationToken(config, user.id, user.email);
      }

      response.json({
        ok: true
      });
    } catch (error) {
      next(error);
    }
  });

  router.delete("/account", requireAuth(config, authUserLookup), async (request, response, next) => {
    try {
      if (!isAuthenticatedRequest(request)) {
        throw unauthorized();
      }

      const input = parseBody(deleteAccountSchema, request.body);
      const user = await prisma.user.findUnique({
        where: { id: request.auth.userId }
      });

      if (!user || !(await verifyPassword(input.password, user.passwordHash))) {
        throw forbidden("PASSWORD_CONFIRMATION_FAILED", "Password confirmation failed.");
      }

      const now = new Date();
      const anonymizedEmail = `deleted+${user.id}@accounts.bphealth.invalid`;
      const anonymizedPasswordHash = await hashPassword(randomUUID());

      await prisma.$transaction([
        prisma.refreshToken.updateMany({
          where: { userId: user.id, revokedAt: null },
          data: { revokedAt: now }
        }),
        prisma.emailVerificationToken.updateMany({
          where: { userId: user.id, consumedAt: null },
          data: { consumedAt: now }
        }),
        prisma.userProfile.updateMany({
          where: { userId: user.id },
          data: { displayName: `研究参与者-${user.id.slice(0, 8)}` }
        }),
        prisma.user.update({
          where: { id: user.id },
          data: {
            researchEmail: user.researchEmail ?? user.email,
            email: anonymizedEmail,
            passwordHash: anonymizedPasswordHash,
            emailVerifiedAt: null,
            deletedAt: now
          }
        })
      ]);

      response.sendStatus(204);
    } catch (error) {
      next(error);
    }
  });

  return router;
}

async function issueAuthResponse(config: ServerConfig, userId: string, deviceIdInput: string | undefined) {
  const user = await prisma.user.findUniqueOrThrow({
    where: { id: userId },
    include: { profile: true }
  });
  const refreshToken = issueRefreshToken(config);
  const deviceId = deviceIdInput ?? makeDeviceId();

  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: refreshToken.hash,
      deviceId,
      expiresAt: refreshToken.expiresAt
    }
  });

  return {
    accessToken: signAccessToken(config, {
      sub: user.id,
      email: user.email
    }),
    accessTokenExpiresInSeconds: config.accessTokenTTLSeconds,
    refreshToken: refreshToken.token,
    refreshTokenExpiresAt: refreshToken.expiresAt.toISOString(),
    deviceId,
    user: serializeUser(user)
  };
}

async function createAndLogVerificationToken(config: ServerConfig, userId: string, email: string): Promise<void> {
  const verificationToken = issueVerificationToken(config);

  await prisma.emailVerificationToken.create({
    data: {
      userId,
      tokenHash: verificationToken.hash,
      expiresAt: verificationToken.expiresAt
    }
  });

  const verificationURL = `${config.emailVerificationBaseURL}?token=${encodeURIComponent(verificationToken.token)}`;
  console.log(`[dev-email] Verify ${email}: ${verificationURL}`);
}

function serializeUser(user: {
  id: string;
  email: string;
  emailVerifiedAt: Date | null;
  profile: { completedAt: Date } | null;
}) {
  return {
    id: user.id,
    email: user.email,
    emailVerified: Boolean(user.emailVerifiedAt),
    profileCompleted: Boolean(user.profile?.completedAt)
  };
}

function isUniqueConstraintError(error: unknown): boolean {
  return typeof error === "object"
    && error !== null
    && "code" in error
    && error.code === "P2002";
}
