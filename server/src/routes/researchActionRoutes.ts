import { Prisma, type DailyActionSnapshot } from "@prisma/client";
import { Router, type Request } from "express";
import { z } from "zod";
import type { ServerConfig } from "../config.js";
import { isAuthenticatedRequest, requireAuth, type AuthUserLookup } from "../auth/authMiddleware.js";
import { prisma } from "../db/prisma.js";
import { unauthorized } from "../errors.js";
import { parseBody, parseQuery } from "./validation.js";

const localDaySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(isValidLocalDay);
const optionalText = (maximum: number) => z.string().trim().max(maximum).nullable();

export const researchActionItemSchema = z.object({
  id: z.string().uuid(),
  type: z.enum(["walk", "diet", "bpRecheck", "rest", "hydration", "sleep", "custom"]),
  title: z.string().trim().min(1).max(100),
  description: z.string().trim().max(1_500),
  reason: z.string().trim().max(1_500),
  scheduledStartAt: z.string().datetime({ offset: true }),
  scheduledEndAt: z.string().datetime({ offset: true }),
  durationMinutes: z.number().int().min(0).max(1_440),
  status: z.enum(["pending", "in_progress", "completed", "skipped", "missed"]),
  effectiveStatus: z.enum(["pending", "in_progress", "completed", "skipped", "missed"]),
  completedAt: z.string().datetime({ offset: true }).nullable(),
  sortOrder: z.number().int().min(0).max(100),
  bloodPressureText: optionalText(100),
  adviceText: optionalText(3_000),
  exerciseId: optionalText(100),
  exerciseScene: optionalText(80),
  exerciseEnergy: optionalText(80),
  exerciseContexts: z.array(z.string().trim().min(1).max(80)).max(12),
  exerciseMovementAdvice: optionalText(1_500),
  exerciseIntensityAdvice: optionalText(1_500),
  actualStartedAt: z.string().datetime({ offset: true }).nullable(),
  actualEndedAt: z.string().datetime({ offset: true }).nullable(),
  actualDurationSeconds: z.number().int().min(0).max(86_400).nullable(),
  completionMode: optionalText(40),
  clientUpdatedAt: z.string().datetime({ offset: true })
}).strict();

const snapshotInputSchema = z.object({
  localDay: localDaySchema,
  timeZone: z.string().trim().min(1).max(64),
  capturedAt: z.string().datetime({ offset: true }),
  items: z.array(researchActionItemSchema).max(40).refine(
    (items) => new Set(items.map((item) => item.id)).size === items.length,
    { message: "Action item ids must be unique." }
  )
}).strict();

const listSnapshotsQuerySchema = z.object({
  from: localDaySchema.optional(),
  to: localDaySchema.optional()
}).strict().refine(
  (value) => !value.from || !value.to || value.from <= value.to,
  { message: "from must not be after to." }
);

export type ResearchActionItem = z.infer<typeof researchActionItemSchema>;
export type ResearchSnapshotInput = z.infer<typeof snapshotInputSchema>;

export interface ResearchSnapshotRecord {
  id: string;
  userId: string;
  localDay: string;
  timeZone: string;
  version: number;
  items: ResearchActionItem[];
  totalCount: number;
  completedCount: number;
  capturedAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface ResearchSyncResult {
  applied: boolean;
  version: number;
  eventCount: number;
  capturedAt: Date;
}

export interface ResearchActionRepository {
  sync(userId: string, input: ResearchSnapshotInput): Promise<ResearchSyncResult>;
  list(userId: string, from?: string, to?: string): Promise<ResearchSnapshotRecord[]>;
}

export interface ResearchActionRouterDependencies {
  authUserLookup?: AuthUserLookup;
  repository?: ResearchActionRepository;
}

export function createResearchActionRouter(
  config: ServerConfig,
  dependencies: ResearchActionRouterDependencies = {}
): Router {
  const router = Router();
  const repository = dependencies.repository ?? prismaResearchActionRepository;
  router.use(requireAuth(config, dependencies.authUserLookup));

  router.post("/sync", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const body = parseBody(snapshotInputSchema, request.body);
      const result = await repository.sync(auth.userId, body);
      response.json({
        applied: result.applied,
        version: result.version,
        eventCount: result.eventCount,
        capturedAt: result.capturedAt.toISOString()
      });
    } catch (error) {
      next(error);
    }
  });

  router.get("/days", async (request, response, next) => {
    try {
      const auth = authFromRequest(request);
      const query = parseQuery(listSnapshotsQuerySchema, request.query);
      const snapshots = await repository.list(auth.userId, query.from, query.to);
      response.json({ snapshots: snapshots.map(serializeSnapshot) });
    } catch (error) {
      next(error);
    }
  });

  return router;
}

export interface ResearchActionChange {
  itemId: string;
  eventType: "created" | "deleted" | "status_changed" | "rescheduled" | "updated";
  beforeState: ResearchActionItem | null;
  afterState: ResearchActionItem | null;
}

export function deriveResearchActionChanges(
  before: ResearchActionItem[],
  after: ResearchActionItem[]
): ResearchActionChange[] {
  const beforeByID = new Map(before.map((item) => [item.id, item]));
  const afterByID = new Map(after.map((item) => [item.id, item]));
  const ids = Array.from(new Set([...beforeByID.keys(), ...afterByID.keys()])).sort();

  return ids.flatMap((itemId): ResearchActionChange[] => {
    const beforeState = beforeByID.get(itemId) ?? null;
    const afterState = afterByID.get(itemId) ?? null;
    if (!beforeState && afterState) {
      return [{ itemId, eventType: "created", beforeState, afterState }];
    }
    if (beforeState && !afterState) {
      return [{ itemId, eventType: "deleted", beforeState, afterState }];
    }
    if (!beforeState || !afterState || stableJSON(beforeState) === stableJSON(afterState)) {
      return [];
    }

    let eventType: ResearchActionChange["eventType"] = "updated";
    if (beforeState.status !== afterState.status) {
      eventType = "status_changed";
    } else if (
      beforeState.scheduledStartAt !== afterState.scheduledStartAt
      || beforeState.scheduledEndAt !== afterState.scheduledEndAt
      || beforeState.durationMinutes !== afterState.durationMinutes
    ) {
      eventType = "rescheduled";
    }
    return [{ itemId, eventType, beforeState, afterState }];
  });
}

export const prismaResearchActionRepository: ResearchActionRepository = {
  async sync(userId, input) {
    return prisma.$transaction(async (transaction) => {
      // SwiftUI can emit closely spaced state changes. Serialising a participant's
      // day prevents concurrent requests from deriving events from one stale state.
      await transaction.$queryRaw<Array<{ locked: number }>>`
        SELECT 1 AS locked
        FROM pg_advisory_xact_lock(hashtext(${`research-action:${userId}:${input.localDay}`}))
      `;
      const existing = await transaction.dailyActionSnapshot.findUnique({
        where: { userId_localDay: { userId, localDay: input.localDay } }
      });
      const capturedAt = new Date(input.capturedAt);
      if (existing && capturedAt < existing.capturedAt) {
        return {
          applied: false,
          version: existing.version,
          eventCount: 0,
          capturedAt: existing.capturedAt
        };
      }

      const beforeItems = existing ? parseStoredItems(existing.items) : [];
      const changes = deriveResearchActionChanges(beforeItems, input.items);
      const version = existing ? existing.version + (changes.length > 0 ? 1 : 0) : 1;
      const totalCount = input.items.length;
      const completedCount = input.items.filter((item) => item.status === "completed").length;

      await transaction.dailyActionSnapshot.upsert({
        where: { userId_localDay: { userId, localDay: input.localDay } },
        create: {
          userId,
          localDay: input.localDay,
          timeZone: input.timeZone,
          version,
          items: input.items as Prisma.InputJsonValue,
          totalCount,
          completedCount,
          capturedAt
        },
        update: {
          timeZone: input.timeZone,
          version,
          items: input.items as Prisma.InputJsonValue,
          totalCount,
          completedCount,
          capturedAt
        }
      });

      if (changes.length > 0) {
        await transaction.actionEvent.createMany({
          data: changes.map((change) => ({
            userId,
            localDay: input.localDay,
            itemId: change.itemId,
            eventType: change.eventType,
            snapshotVersion: version,
            beforeState: change.beforeState === null
              ? Prisma.DbNull
              : change.beforeState as Prisma.InputJsonValue,
            afterState: change.afterState === null
              ? Prisma.DbNull
              : change.afterState as Prisma.InputJsonValue,
            occurredAt: capturedAt
          }))
        });
      }

      return { applied: true, version, eventCount: changes.length, capturedAt };
    });
  },

  async list(userId, from, to) {
    const records = await prisma.dailyActionSnapshot.findMany({
      where: {
        userId,
        ...(from || to ? {
          localDay: {
            ...(from ? { gte: from } : {}),
            ...(to ? { lte: to } : {})
          }
        } : {})
      },
      orderBy: { localDay: "desc" },
      take: 60
    });
    return records.map(snapshotFromPrisma);
  }
};

function parseStoredItems(value: Prisma.JsonValue): ResearchActionItem[] {
  const parsed = z.array(researchActionItemSchema).safeParse(value);
  return parsed.success ? parsed.data : [];
}

function snapshotFromPrisma(record: DailyActionSnapshot): ResearchSnapshotRecord {
  return { ...record, items: parseStoredItems(record.items) };
}

function serializeSnapshot(snapshot: ResearchSnapshotRecord) {
  return {
    localDay: snapshot.localDay,
    timeZone: snapshot.timeZone,
    version: snapshot.version,
    items: snapshot.items,
    totalCount: snapshot.totalCount,
    completedCount: snapshot.completedCount,
    capturedAt: snapshot.capturedAt.toISOString(),
    updatedAt: snapshot.updatedAt.toISOString()
  };
}

function stableJSON(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(stableJSON).join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, child]) => `${JSON.stringify(key)}:${stableJSON(child)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function authFromRequest(request: Request) {
  if (!isAuthenticatedRequest(request)) {
    throw unauthorized();
  }
  return request.auth;
}

function isValidLocalDay(value: string): boolean {
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year
    && date.getUTCMonth() === month - 1
    && date.getUTCDate() === day;
}
