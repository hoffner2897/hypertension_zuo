import { Prisma } from "@prisma/client";
import { Router, type Request } from "express";
import { z } from "zod";
import type { ServerConfig } from "../config.js";
import { isAuthenticatedRequest, requireAuth } from "../auth/authMiddleware.js";
import type { AuthUserLookup } from "../auth/authMiddleware.js";
import { prisma } from "../db/prisma.js";
import { conflict, unauthorized } from "../errors.js";
import { parseBody, parseQuery } from "./validation.js";

const actionStatusSchema = z.enum(["pending", "in_progress", "completed", "skipped", "missed"]);
const localDaySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(isValidLocalDay);
const nonEmptyLabel = (maximum: number) => z.string().trim().min(1).max(maximum);

const listExerciseActionsQuerySchema = z.object({
  localDay: localDaySchema
}).strict();

const exerciseActionIDParamsSchema = z.object({
  id: z.string().uuid()
}).strict();

const exerciseActionInputSchema = z.object({
  exerciseId: nonEmptyLabel(100),
  title: nonEmptyLabel(100),
  scene: nonEmptyLabel(80),
  energy: nonEmptyLabel(80),
  contexts: z.array(nonEmptyLabel(80)).max(12).refine(
    (values) => new Set(values).size === values.length,
    { message: "Contexts must not contain duplicates." }
  ),
  scheduledStartAt: z.string().datetime({ offset: true }),
  durationMinutes: z.number().int().min(1).max(180),
  status: actionStatusSchema,
  completedAt: z.string().datetime({ offset: true }).nullable(),
  actualStartedAt: z.string().datetime({ offset: true }).nullable(),
  timerLastResumedAt: z.string().datetime({ offset: true }).nullable(),
  timerAccumulatedSeconds: z.number().int().min(0).max(86_400),
  actualEndedAt: z.string().datetime({ offset: true }).nullable(),
  actualDurationSeconds: z.number().int().min(0).max(86_400).nullable(),
  completionMode: z.enum(["timer_completed", "ended_early", "manual_completed"]).nullable(),
  movementAdvice: nonEmptyLabel(1_500),
  intensityAdvice: nonEmptyLabel(1_500),
  localDay: localDaySchema,
  clientUpdatedAt: z.string().datetime({ offset: true })
}).strict().superRefine((value, context) => {
  if (value.status === "completed" && value.completedAt === null) {
    context.addIssue({
      code: "custom",
      path: ["completedAt"],
      message: "A completed action must include completedAt."
    });
  }

  if (value.status !== "completed" && value.completedAt !== null) {
    context.addIssue({
      code: "custom",
      path: ["completedAt"],
      message: "Only a completed action may include completedAt."
    });
  }
});

export type ExerciseActionStatusValue = z.infer<typeof actionStatusSchema>;

export interface ExerciseActionWriteInput {
  exerciseId: string;
  title: string;
  scene: string;
  energy: string;
  contexts: string[];
  scheduledStartAt: Date;
  durationMinutes: number;
  status: ExerciseActionStatusValue;
  completedAt: Date | null;
  actualStartedAt: Date | null;
  timerLastResumedAt: Date | null;
  timerAccumulatedSeconds: number;
  actualEndedAt: Date | null;
  actualDurationSeconds: number | null;
  completionMode: string | null;
  movementAdvice: string;
  intensityAdvice: string;
  localDay: string;
  clientUpdatedAt: Date;
}

export interface ExerciseActionRecord extends ExerciseActionWriteInput {
  id: string;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}

export interface ExerciseActionRepository {
  listByLocalDay(userId: string, localDay: string): Promise<ExerciseActionRecord[]>;
  findByID(id: string): Promise<ExerciseActionRecord | null>;
  create(userId: string, id: string, input: ExerciseActionWriteInput): Promise<ExerciseActionRecord>;
  updateIfNotOlder(
    userId: string,
    id: string,
    input: ExerciseActionWriteInput
  ): Promise<boolean>;
  softDelete(userId: string, id: string, deletedAt: Date): Promise<boolean>;
}

export interface ExerciseActionRouterDependencies {
  authUserLookup?: AuthUserLookup;
  repository?: ExerciseActionRepository;
}

export class ExerciseActionIDCollisionError extends Error {}

export function createExerciseActionRouter(
  config: ServerConfig,
  dependencies: ExerciseActionRouterDependencies = {}
): Router {
  const router = Router();
  const repository = dependencies.repository ?? prismaExerciseActionRepository;
  router.use(requireAuth(config, dependencies.authUserLookup));

  router.get("/", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const query = parseQuery(listExerciseActionsQuerySchema, request.query);
      const actions = await repository.listByLocalDay(auth.userId, query.localDay);
      response.json({ actions: actions.map(serializeExerciseAction) });
    } catch (error) {
      next(error);
    }
  });

  router.put("/:id", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const params = parseBody(exerciseActionIDParamsSchema, request.params);
      const body = parseBody(exerciseActionInputSchema, request.body);
      const result = await putExerciseAction(repository, auth.userId, params.id, {
        ...body,
        scheduledStartAt: new Date(body.scheduledStartAt),
        completedAt: body.completedAt ? new Date(body.completedAt) : null,
        actualStartedAt: body.actualStartedAt ? new Date(body.actualStartedAt) : null,
        timerLastResumedAt: body.timerLastResumedAt ? new Date(body.timerLastResumedAt) : null,
        actualEndedAt: body.actualEndedAt ? new Date(body.actualEndedAt) : null,
        clientUpdatedAt: new Date(body.clientUpdatedAt)
      });

      response.json({
        action: serializeExerciseAction(result.action),
        applied: result.applied
      });
    } catch (error) {
      next(error);
    }
  });

  router.delete("/:id", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const params = parseBody(exerciseActionIDParamsSchema, request.params);
      const existing = await repository.findByID(params.id);
      if (!existing) {
        response.status(204).send();
        return;
      }
      assertOwnership(existing, auth.userId);
      await repository.softDelete(auth.userId, params.id, new Date());
      response.status(204).send();
    } catch (error) {
      next(error);
    }
  });

  return router;
}

export async function putExerciseAction(
  repository: ExerciseActionRepository,
  userId: string,
  id: string,
  input: ExerciseActionWriteInput,
  retriedAfterCollision = false
): Promise<{ action: ExerciseActionRecord; applied: boolean }> {
  const existing = await repository.findByID(id);

  if (existing) {
    assertOwnership(existing, userId);
    if (input.clientUpdatedAt.getTime() < existing.clientUpdatedAt.getTime()) {
      return { action: existing, applied: false };
    }

    const applied = await repository.updateIfNotOlder(userId, id, input);
    const current = await repository.findByID(id);
    if (!current) {
      throw new Error("Exercise action disappeared during update.");
    }
    assertOwnership(current, userId);
    return { action: current, applied };
  }

  try {
    const created = await repository.create(userId, id, input);
    return { action: created, applied: true };
  } catch (error) {
    if (error instanceof ExerciseActionIDCollisionError && !retriedAfterCollision) {
      return putExerciseAction(repository, userId, id, input, true);
    }
    if (error instanceof ExerciseActionIDCollisionError) {
      throw idConflict();
    }
    throw error;
  }
}

export const prismaExerciseActionRepository: ExerciseActionRepository = {
  listByLocalDay(userId, localDay) {
    return prisma.exerciseAction.findMany({
      where: { userId, localDay, deletedAt: null },
      orderBy: [{ scheduledStartAt: "asc" }, { createdAt: "asc" }]
    });
  },

  findByID(id) {
    return prisma.exerciseAction.findUnique({ where: { id } });
  },

  async create(userId, id, input) {
    try {
      return await prisma.exerciseAction.create({
        data: { id, userId, ...input }
      });
    } catch (error) {
      if (isUniqueConstraintError(error)) {
        throw new ExerciseActionIDCollisionError();
      }
      throw error;
    }
  },

  async updateIfNotOlder(userId, id, input) {
    const result = await prisma.exerciseAction.updateMany({
      where: {
        id,
        userId,
        clientUpdatedAt: { lte: input.clientUpdatedAt },
        deletedAt: null
      },
      data: input
    });
    return result.count === 1;
  },

  async softDelete(userId, id, deletedAt) {
    const result = await prisma.exerciseAction.updateMany({
      where: { id, userId, deletedAt: null },
      data: { deletedAt, timerLastResumedAt: null }
    });
    return result.count === 1;
  }
};

function serializeExerciseAction(action: ExerciseActionRecord) {
  return {
    id: action.id,
    exerciseId: action.exerciseId,
    title: action.title,
    scene: action.scene,
    energy: action.energy,
    contexts: action.contexts,
    scheduledStartAt: action.scheduledStartAt.toISOString(),
    durationMinutes: action.durationMinutes,
    status: action.status,
    completedAt: action.completedAt?.toISOString() ?? null,
    actualStartedAt: action.actualStartedAt?.toISOString() ?? null,
    timerLastResumedAt: action.timerLastResumedAt?.toISOString() ?? null,
    timerAccumulatedSeconds: action.timerAccumulatedSeconds,
    actualEndedAt: action.actualEndedAt?.toISOString() ?? null,
    actualDurationSeconds: action.actualDurationSeconds,
    completionMode: action.completionMode,
    movementAdvice: action.movementAdvice,
    intensityAdvice: action.intensityAdvice,
    localDay: action.localDay,
    clientUpdatedAt: action.clientUpdatedAt.toISOString(),
    createdAt: action.createdAt.toISOString(),
    updatedAt: action.updatedAt.toISOString()
  };
}

function authFromRequest(request: Request) {
  if (!isAuthenticatedRequest(request)) {
    throw unauthorized();
  }
  return request.auth;
}

function assertOwnership(action: ExerciseActionRecord, userId: string): void {
  if (action.userId !== userId) {
    throw idConflict();
  }
}

function idConflict() {
  return conflict(
    "EXERCISE_ACTION_ID_CONFLICT",
    "This exercise action id is already in use."
  );
}

function isUniqueConstraintError(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002";
}

function isValidLocalDay(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    return false;
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year
    && date.getUTCMonth() === month - 1
    && date.getUTCDate() === day;
}
