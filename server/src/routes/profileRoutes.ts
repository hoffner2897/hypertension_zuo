import { Router } from "express";
import { z } from "zod";
import type { ServerConfig } from "../config.js";
import { isAuthenticatedRequest, requireAuth } from "../auth/authMiddleware.js";
import type { AuthUserLookup } from "../auth/authMiddleware.js";
import { prisma } from "../db/prisma.js";
import { unauthorized } from "../errors.js";
import { parseBody } from "./validation.js";

const currentYear = new Date().getUTCFullYear();

const profileSchema = z.object({
  displayName: z.string().trim().min(1).max(80),
  birthYear: z.number().int().min(1900).max(currentYear),
  sex: z.enum(["female", "male", "other", "prefer_not_to_say"]),
  heightCm: z.number().positive().max(260).nullable().optional(),
  weightKg: z.number().positive().max(500).nullable().optional(),
  todaySteps: z.number().int().min(0).max(200000).nullable().optional(),
  dailySteps: z.number().int().min(0).max(200000).nullable().optional(),
  exerciseMinutes: z.number().int().min(0).max(1440).nullable().optional(),
  restingHeartRate: z.number().int().min(20).max(240).nullable().optional(),
  sleepHours: z.number().min(0).max(24).nullable().optional(),
  healthDataSource: z.string().trim().max(80).nullable().optional(),
  healthDataSyncedAt: z.string().datetime().nullable().optional()
});

export function createProfileRouter(config: ServerConfig, authUserLookup?: AuthUserLookup): Router {
  const router = Router();
  router.use(requireAuth(config, authUserLookup));

  router.get("/", async (request, response, next) => {
    try {
      if (!isAuthenticatedRequest(request)) {
        throw unauthorized();
      }

      const profile = await prisma.userProfile.findUnique({
        where: { userId: request.auth.userId }
      });

      response.json({
        profile: profile ? serializeProfile(profile) : null
      });
    } catch (error) {
      next(error);
    }
  });

  router.put("/", async (request, response, next) => {
    try {
      if (!isAuthenticatedRequest(request)) {
        throw unauthorized();
      }

      const input = parseBody(profileSchema, request.body);
      const now = new Date();
      const todaySteps = input.todaySteps ?? input.dailySteps;

      const profile = await prisma.userProfile.upsert({
        where: { userId: request.auth.userId },
        create: {
          userId: request.auth.userId,
          displayName: input.displayName,
          birthYear: input.birthYear,
          sex: input.sex,
          heightCm: input.heightCm,
          weightKg: input.weightKg,
          dailySteps: todaySteps,
          exerciseMinutes: input.exerciseMinutes,
          restingHeartRate: input.restingHeartRate,
          sleepHours: input.sleepHours,
          healthDataSource: input.healthDataSource,
          healthDataSyncedAt: input.healthDataSyncedAt ? new Date(input.healthDataSyncedAt) : null,
          completedAt: now
        },
        update: {
          displayName: input.displayName,
          birthYear: input.birthYear,
          sex: input.sex,
          heightCm: input.heightCm,
          weightKg: input.weightKg,
          dailySteps: todaySteps,
          exerciseMinutes: input.exerciseMinutes,
          restingHeartRate: input.restingHeartRate,
          sleepHours: input.sleepHours,
          healthDataSource: input.healthDataSource,
          healthDataSyncedAt: input.healthDataSyncedAt ? new Date(input.healthDataSyncedAt) : null,
          completedAt: now
        }
      });

      response.json({
        profile: serializeProfile(profile)
      });
    } catch (error) {
      next(error);
    }
  });

  return router;
}

function serializeProfile(profile: {
  id: string;
  displayName: string;
  birthYear: number;
  sex: string;
  heightCm: unknown;
  weightKg: unknown;
  dailySteps: number | null;
  exerciseMinutes: number | null;
  restingHeartRate: number | null;
  sleepHours: unknown;
  healthDataSource: string | null;
  healthDataSyncedAt: Date | null;
  completedAt: Date;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    id: profile.id,
    displayName: profile.displayName,
    birthYear: profile.birthYear,
    sex: profile.sex,
    heightCm: decimalToNumber(profile.heightCm),
    weightKg: decimalToNumber(profile.weightKg),
    todaySteps: profile.dailySteps,
    dailySteps: profile.dailySteps,
    exerciseMinutes: profile.exerciseMinutes,
    restingHeartRate: profile.restingHeartRate,
    sleepHours: decimalToNumber(profile.sleepHours),
    healthDataSource: profile.healthDataSource,
    healthDataSyncedAt: profile.healthDataSyncedAt?.toISOString() ?? null,
    completedAt: profile.completedAt.toISOString(),
    createdAt: profile.createdAt.toISOString(),
    updatedAt: profile.updatedAt.toISOString()
  };
}

function decimalToNumber(value: unknown): number | null {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === "number") {
    return value;
  }

  if (typeof value === "object" && "toNumber" in value && typeof value.toNumber === "function") {
    return value.toNumber();
  }

  return Number(value);
}
