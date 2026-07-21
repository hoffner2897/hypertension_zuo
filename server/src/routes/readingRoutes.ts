import { Router, type NextFunction, type Request, type Response } from "express";
import { z } from "zod";
import type { ServerConfig } from "../config.js";
import { isAuthenticatedRequest, requireAuth } from "../auth/authMiddleware.js";
import type { AuthUserLookup } from "../auth/authMiddleware.js";
import { prisma } from "../db/prisma.js";
import { badRequest, unauthorized } from "../errors.js";
import { parseBody, parseQuery } from "./validation.js";
import { makeRuleBasedInterpretation, stripInternalFields } from "../domain/bloodPressureInterpretation.js";
import { OpenAIBPInterpretationService } from "../services/openAIBPInterpretationService.js";

const readingSource = z.enum(["manual", "camera_mock", "camera_ocr", "health_import"]);

const readingShape = {
  clientId: z.string().uuid(),
  systolic: z.number().int().min(40).max(260),
  diastolic: z.number().int().min(30).max(180),
  pulse: z.number().int().min(30).max(240).nullable().optional(),
  measuredAt: z.string().datetime(),
  source: readingSource,
  note: z.string().trim().max(500).nullable().optional()
};

const readingInputSchema = z.object(readingShape).refine((value) => value.systolic > value.diastolic, {
  message: "Systolic must be greater than diastolic.",
  path: ["systolic"]
});

const updateReadingSchema = z.object({
  systolic: readingShape.systolic.optional(),
  diastolic: readingShape.diastolic.optional(),
  pulse: readingShape.pulse,
  measuredAt: readingShape.measuredAt.optional(),
  source: readingShape.source.optional(),
  note: readingShape.note
}).refine((value) => {
  if (value.systolic === undefined || value.diastolic === undefined) {
    return true;
  }

  return value.systolic > value.diastolic;
}, {
  message: "Systolic must be greater than diastolic.",
  path: ["systolic"]
});

const listReadingsSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  cursor: z.string().datetime().optional(),
  includeDeleted: z
    .enum(["true", "false"])
    .optional()
    .transform((value) => value === "true")
});

const syncReadingsSchema = z.object({
  readings: z.array(readingInputSchema).max(100)
});

const recentInterpretationReadingSchema = z.object({
  systolicBp: z.number().int().min(40).max(260),
  diastolicBp: z.number().int().min(30).max(180),
  measurementTime: z.string().datetime().nullable().optional()
}).refine((value) => value.systolicBp > value.diastolicBp, {
  message: "Systolic must be greater than diastolic.",
  path: ["systolicBp"]
});

const medicalContextSchema = z.object({
  knownHypertension: z.boolean().optional(),
  diabetes: z.boolean().optional(),
  kidneyDisease: z.boolean().optional(),
  pregnancy: z.boolean().optional(),
  cardiovascularDisease: z.boolean().optional(),
  currentBpMedication: z.boolean().optional()
}).optional();

const measurementContextSchema = z.object({
  rested5Min: z.boolean().optional(),
  caffeineExerciseSmokingAlcoholRecently: z.boolean().optional(),
  correctCuff: z.boolean().optional(),
  seated: z.boolean().optional(),
  armAtHeartLevel: z.boolean().optional()
}).optional();

const interpretationRequestSchema = z.object({
  systolicBp: z.number().int().min(40).max(260),
  diastolicBp: z.number().int().min(30).max(180),
  bpMonitorPulse: z.number().int().min(30).max(240).nullable().optional(),
  measurementTime: z.string().datetime(),
  recentBpReadings: z.array(recentInterpretationReadingSchema).max(30).optional(),
  symptoms: z.array(z.string().trim().min(1).max(80)).max(20).optional(),
  medicalContext: medicalContextSchema,
  measurementContext: measurementContextSchema
}).refine((value) => value.systolicBp > value.diastolicBp, {
  message: "Systolic must be greater than diastolic.",
  path: ["systolicBp"]
});

export function createReadingRouter(config: ServerConfig, authUserLookup?: AuthUserLookup): Router {
  const router = Router();
  router.use(requireAuth(config, authUserLookup));

  router.get("/", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const query = parseQuery(listReadingsSchema, request.query);
      const readings = await prisma.bloodPressureReading.findMany({
        where: {
          userId: auth.userId,
          deletedAt: query.includeDeleted ? undefined : null,
          measuredAt: query.cursor ? { lt: new Date(query.cursor) } : undefined
        },
        orderBy: { measuredAt: "desc" },
        take: query.limit
      });

      response.json({
        readings: readings.map(serializeReading),
        nextCursor: readings.length === query.limit ? readings[readings.length - 1]?.measuredAt.toISOString() : null
      });
    } catch (error) {
      next(error);
    }
  });

  router.post("/interpretation", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const input = parseBody(interpretationRequestSchema, request.body);
      const profile = await prisma.userProfile.findUnique({
        where: { userId: auth.userId }
      });

      const interpretationInput = {
        age: profile ? new Date().getUTCFullYear() - profile.birthYear : null,
        sex: profile?.sex ?? null,
        heightCm: decimalToNumber(profile?.heightCm),
        weightKg: decimalToNumber(profile?.weightKg),
        todaySteps: profile?.dailySteps ?? null,
        yesterdayExerciseMinutes: profile?.exerciseMinutes ?? null,
        restingHeartRate: profile?.restingHeartRate ?? null,
        averageSleepHoursLast7Days: decimalToNumber(profile?.sleepHours),
        systolicBp: input.systolicBp,
        diastolicBp: input.diastolicBp,
        bpMonitorPulse: input.bpMonitorPulse ?? null,
        measurementTime: input.measurementTime,
        recentBpReadings: input.recentBpReadings ?? [],
        symptoms: input.symptoms ?? [],
        medicalContext: input.medicalContext,
        measurementContext: input.measurementContext
      };

      const baseInterpretation = makeRuleBasedInterpretation(interpretationInput);
      let interpretation = stripInternalFields(baseInterpretation);

      if (config.openAIAPIKey) {
        try {
          interpretation = await new OpenAIBPInterpretationService({
            apiKey: config.openAIAPIKey,
            model: config.openAIModel,
            proxyURL: config.openAIProxyURL
          }).interpret(interpretationInput, baseInterpretation);
        } catch (error) {
          console.warn("OpenAI BP interpretation failed; returning rule-based interpretation.", error);
        }
      }

      response.json({ interpretation });
    } catch (error) {
      next(error);
    }
  });

  router.post("/", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const input = parseBody(readingInputSchema, request.body);
      const reading = await upsertReading(auth.userId, input);

      response.status(201).json({
        reading: serializeReading(reading)
      });
    } catch (error) {
      next(error);
    }
  });

  router.put("/:id", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const input = parseBody(updateReadingSchema, request.body);
      const existingReading = await prisma.bloodPressureReading.findFirst({
        where: {
          id: request.params.id,
          userId: auth.userId,
          deletedAt: null
        }
      });

      if (!existingReading) {
        response.status(404).json({ code: "READING_NOT_FOUND" });
        return;
      }

      const systolic = input.systolic ?? existingReading.systolic;
      const diastolic = input.diastolic ?? existingReading.diastolic;
      if (systolic <= diastolic) {
        throw badRequest("INVALID_READING_VALUES", "Systolic must be greater than diastolic.");
      }

      const reading = await prisma.bloodPressureReading.update({
        where: { id: existingReading.id },
        data: {
          systolic: input.systolic,
          diastolic: input.diastolic,
          pulse: input.pulse,
          measuredAt: input.measuredAt ? new Date(input.measuredAt) : undefined,
          source: input.source,
          note: input.note
        }
      });

      response.json({
        reading: serializeReading(reading)
      });
    } catch (error) {
      next(error);
    }
  });

  router.delete("/:id", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      await prisma.bloodPressureReading.updateMany({
        where: {
          id: request.params.id,
          userId: auth.userId,
          deletedAt: null
        },
        data: { deletedAt: new Date() }
      });

      response.sendStatus(204);
    } catch (error) {
      next(error);
    }
  });

  router.post("/sync", makeSyncHandler());

  return router;
}

export function createReadingSyncRouter(config: ServerConfig, authUserLookup?: AuthUserLookup): Router {
  const router = Router();
  router.use(requireAuth(config, authUserLookup));
  router.post("/", makeSyncHandler());

  return router;
}

function makeSyncHandler() {
  return async (request: Request, response: Response, next: NextFunction) => {
    try {
      const auth = authFromRequest(request);
      const input = parseBody(syncReadingsSchema, request.body);
      const readings = [];

      for (const readingInput of input.readings) {
        readings.push(await upsertReading(auth.userId, readingInput));
      }

      response.json({
        readings: readings.map(serializeReading)
      });
    } catch (error) {
      next(error);
    }
  };
}

function authFromRequest(request: Request) {
  if (!isAuthenticatedRequest(request)) {
    throw unauthorized();
  }

  return request.auth;
}

async function upsertReading(userId: string, input: z.infer<typeof readingInputSchema>) {
  return prisma.bloodPressureReading.upsert({
    where: {
      userId_clientId: {
        userId,
        clientId: input.clientId
      }
    },
    create: {
      userId,
      clientId: input.clientId,
      systolic: input.systolic,
      diastolic: input.diastolic,
      pulse: input.pulse,
      measuredAt: new Date(input.measuredAt),
      source: input.source,
      note: input.note
    },
    update: {
      systolic: input.systolic,
      diastolic: input.diastolic,
      pulse: input.pulse,
      measuredAt: new Date(input.measuredAt),
      source: input.source,
      note: input.note,
      deletedAt: null
    }
  });
}

function serializeReading(reading: {
  id: string;
  userId: string;
  clientId: string;
  systolic: number;
  diastolic: number;
  pulse: number | null;
  measuredAt: Date;
  source: string;
  note: string | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}) {
  return {
    id: reading.id,
    userId: reading.userId,
    clientId: reading.clientId,
    systolic: reading.systolic,
    diastolic: reading.diastolic,
    pulse: reading.pulse,
    measuredAt: reading.measuredAt.toISOString(),
    source: reading.source,
    note: reading.note,
    createdAt: reading.createdAt.toISOString(),
    updatedAt: reading.updatedAt.toISOString(),
    deletedAt: reading.deletedAt?.toISOString() ?? null
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
