import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import test from "node:test";
import { createApp } from "../app.js";
import { signAccessToken } from "../auth/tokenUtils.js";
import type { ServerConfig } from "../config.js";
import {
  ExerciseActionIDCollisionError,
  type ExerciseActionRecord,
  type ExerciseActionRepository,
  type ExerciseActionWriteInput
} from "./exerciseActionRoutes.js";

const config: ServerConfig = {
  port: 0,
  recognitionMode: "mock",
  openAIModel: "test-recognition-model",
  openAIActionSuggestionModel: "test-action-model",
  openAIMealAnalysisModel: "test-meal-model",
  bpRecognitionDailyLimit: 30,
  mealAnalysisDailyLimit: 20,
  minimumSupportedIOSBuild: 0,
  iosUpdateURL: "https://testflight.apple.com/join/TyhR9xzw",
  accessTokenSecret: "test-only-access-token-secret-with-enough-entropy",
  accessTokenTTLSeconds: 900,
  refreshTokenTTLDays: 30,
  emailVerificationTTLHours: 24,
  emailVerificationBaseURL: "http://localhost/auth/verify-email"
};

const primaryUserID = "11111111-1111-4111-8111-111111111111";
const secondaryUserID = "22222222-2222-4222-8222-222222222222";
const actionID = "33333333-3333-4333-8333-333333333333";

test("exercise action endpoints require auth and strictly validate input", async () => {
  const repository = new InMemoryExerciseActionRepository();
  await withServer(repository, async (baseURL) => {
    const unauthorizedList = await fetch(`${baseURL}/exercise-actions?localDay=2026-07-22`);
    assert.equal(unauthorizedList.status, 401);

    const token = accessToken(primaryUserID);
    const invalidDay = await fetch(`${baseURL}/exercise-actions?localDay=2026-02-30`, {
      headers: authHeaders(token)
    });
    assert.equal(invalidDay.status, 400);
    assert.equal((await invalidDay.json() as { code: string }).code, "VALIDATION_FAILED");

    const extraQuery = await fetch(`${baseURL}/exercise-actions?localDay=2026-07-22&all=true`, {
      headers: authHeaders(token)
    });
    assert.equal(extraQuery.status, 400);

    const invalidID = await putAction(baseURL, "not-a-uuid", token, makeBody());
    assert.equal(invalidID.response.status, 400);
    assert.equal(invalidID.body.code, "VALIDATION_FAILED");

    const inconsistentCompletion = await putAction(baseURL, actionID, token, {
      ...makeBody(),
      status: "completed",
      completedAt: null
    });
    assert.equal(inconsistentCompletion.response.status, 400);
    assert.equal(inconsistentCompletion.body.code, "VALIDATION_FAILED");

    const duplicateContexts = await putAction(baseURL, actionID, token, {
      ...makeBody(),
      contexts: ["饭后", "饭后"]
    });
    assert.equal(duplicateContexts.response.status, 400);
  });
});

test("exercise actions are created, listed by local day, and updated for their owner", async () => {
  const repository = new InMemoryExerciseActionRepository();
  await withServer(repository, async (baseURL) => {
    const token = accessToken(primaryUserID);
    const created = await putAction(baseURL, actionID, token, makeBody());

    assert.equal(created.response.status, 200);
    assert.equal(created.body.applied, true);
    assert.equal(created.body.action.id, actionID);
    assert.equal(created.body.action.title, "原地踏步");
    assert.equal(created.body.action.clientUpdatedAt, "2026-07-22T09:00:00.000Z");
    assert.equal(typeof created.body.action.updatedAt, "string");
    assert.equal("userId" in created.body.action, false);

    const listed = await getActions(baseURL, token, "2026-07-22");
    assert.equal(listed.response.status, 200);
    assert.equal(listed.body.actions.length, 1);
    assert.equal(listed.body.actions[0].movementAdvice, "身体站直，双脚交替抬起。");

    const otherDay = await getActions(baseURL, token, "2026-07-23");
    assert.deepEqual(otherDay.body.actions, []);

    const equalTimestamp = await putAction(baseURL, actionID, token, {
      ...makeBody(),
      title: "原地踏步（同时间更新）"
    });
    assert.equal(equalTimestamp.body.applied, true);
    assert.equal(equalTimestamp.body.action.title, "原地踏步（同时间更新）");

    const completed = await putAction(baseURL, actionID, token, {
      ...makeBody(),
      status: "completed",
      completedAt: "2026-07-22T09:12:00.000Z",
      clientUpdatedAt: "2026-07-22T09:12:01.000Z"
    });
    assert.equal(completed.body.applied, true);
    assert.equal(completed.body.action.status, "completed");
    assert.equal(completed.body.action.completedAt, "2026-07-22T09:12:00.000Z");
  });
});

test("an older offline write cannot overwrite a newer exercise action", async () => {
  const repository = new InMemoryExerciseActionRepository();
  await withServer(repository, async (baseURL) => {
    const token = accessToken(primaryUserID);
    await putAction(baseURL, actionID, token, {
      ...makeBody(),
      title: "较新的名称",
      clientUpdatedAt: "2026-07-22T10:00:00.000Z"
    });

    const stale = await putAction(baseURL, actionID, token, {
      ...makeBody(),
      title: "离线旧名称",
      clientUpdatedAt: "2026-07-22T09:59:59.999Z"
    });

    assert.equal(stale.response.status, 200);
    assert.equal(stale.body.applied, false);
    assert.equal(stale.body.action.title, "较新的名称");
    assert.equal(stale.body.action.clientUpdatedAt, "2026-07-22T10:00:00.000Z");
  });
});

test("an exercise action UUID owned by another user cannot be overwritten or listed", async () => {
  const repository = new InMemoryExerciseActionRepository();
  await withServer(repository, async (baseURL) => {
    const primaryToken = accessToken(primaryUserID);
    const secondaryToken = accessToken(secondaryUserID);
    await putAction(baseURL, actionID, primaryToken, makeBody());

    const collision = await putAction(baseURL, actionID, secondaryToken, {
      ...makeBody(),
      title: "试图覆盖",
      clientUpdatedAt: "2026-07-22T11:00:00.000Z"
    });
    assert.equal(collision.response.status, 409);
    assert.equal(collision.body.code, "EXERCISE_ACTION_ID_CONFLICT");

    const secondaryList = await getActions(baseURL, secondaryToken, "2026-07-22");
    assert.deepEqual(secondaryList.body.actions, []);

    const primaryList = await getActions(baseURL, primaryToken, "2026-07-22");
    assert.equal(primaryList.body.actions[0].title, "原地踏步");
  });
});

test("deleting today's exercise action soft-deletes it while retaining research fields", async () => {
  const repository = new InMemoryExerciseActionRepository();
  await withServer(repository, async (baseURL) => {
    const token = accessToken(primaryUserID);
    await putAction(baseURL, actionID, token, {
      ...makeBody(),
      status: "completed",
      completedAt: "2026-07-22T09:10:00.000Z",
      actualStartedAt: "2026-07-22T09:00:00.000Z",
      actualEndedAt: "2026-07-22T09:10:00.000Z",
      actualDurationSeconds: 600,
      timerAccumulatedSeconds: 600,
      completionMode: "timer_completed"
    });

    const deleted = await fetch(`${baseURL}/exercise-actions/${actionID}`, {
      method: "DELETE",
      headers: authHeaders(token)
    });
    assert.equal(deleted.status, 204);
    const listed = await getActions(baseURL, token, "2026-07-22");
    assert.deepEqual(listed.body.actions, []);
    const retained = await repository.findByID(actionID);
    assert.equal(retained?.actualDurationSeconds, 600);
    assert.equal(retained?.completionMode, "timer_completed");
    assert.ok(retained?.deletedAt instanceof Date);
  });
});

class InMemoryExerciseActionRepository implements ExerciseActionRepository {
  private readonly records = new Map<string, ExerciseActionRecord>();
  private clock = Date.parse("2026-07-22T08:00:00.000Z");

  async listByLocalDay(userId: string, localDay: string): Promise<ExerciseActionRecord[]> {
    return Array.from(this.records.values())
      .filter((record) => record.userId === userId && record.localDay === localDay && record.deletedAt === null)
      .sort((left, right) => left.scheduledStartAt.getTime() - right.scheduledStartAt.getTime())
      .map(cloneRecord);
  }

  async findByID(id: string): Promise<ExerciseActionRecord | null> {
    const record = this.records.get(id);
    return record ? cloneRecord(record) : null;
  }

  async create(userId: string, id: string, input: ExerciseActionWriteInput): Promise<ExerciseActionRecord> {
    if (this.records.has(id)) {
      throw new ExerciseActionIDCollisionError();
    }
    const now = this.nextTimestamp();
    const record: ExerciseActionRecord = {
      ...cloneInput(input),
      id,
      userId,
      createdAt: now,
      updatedAt: now,
      deletedAt: null
    };
    this.records.set(id, record);
    return cloneRecord(record);
  }

  async updateIfNotOlder(
    userId: string,
    id: string,
    input: ExerciseActionWriteInput
  ): Promise<boolean> {
    const current = this.records.get(id);
    if (!current || current.userId !== userId || current.clientUpdatedAt > input.clientUpdatedAt) {
      return false;
    }
    this.records.set(id, {
      ...current,
      ...cloneInput(input),
      updatedAt: this.nextTimestamp()
    });
    return true;
  }

  async softDelete(userId: string, id: string, deletedAt: Date): Promise<boolean> {
    const current = this.records.get(id);
    if (!current || current.userId !== userId || current.deletedAt !== null) {
      return false;
    }
    this.records.set(id, { ...current, deletedAt: new Date(deletedAt), timerLastResumedAt: null });
    return true;
  }

  private nextTimestamp(): Date {
    this.clock += 1;
    return new Date(this.clock);
  }
}

async function withServer(
  repository: ExerciseActionRepository,
  operation: (baseURL: string) => Promise<void>
): Promise<void> {
  const app = createApp(config, {
    exerciseActionRepository: repository,
    authUserLookup: async (userId) => ({ id: userId, email: `${userId}@example.com` })
  });
  const server = app.listen(0, "127.0.0.1");
  try {
    await new Promise<void>((resolve, reject) => {
      server.once("listening", resolve);
      server.once("error", reject);
    });
    const address = server.address() as AddressInfo;
    await operation(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

function accessToken(userID: string): string {
  return signAccessToken(config, { sub: userID, email: `${userID}@example.com` });
}

function authHeaders(token: string): Record<string, string> {
  return { Authorization: `Bearer ${token}` };
}

function makeBody(): Record<string, unknown> {
  return {
    exerciseId: "indoor-in-place-march",
    title: "原地踏步",
    scene: "室内居家",
    energy: "精力一般",
    contexts: ["久坐后"],
    scheduledStartAt: "2026-07-22T09:00:00.000Z",
    durationMinutes: 10,
    status: "pending",
    completedAt: null,
    actualStartedAt: null,
    timerLastResumedAt: null,
    timerAccumulatedSeconds: 0,
    actualEndedAt: null,
    actualDurationSeconds: null,
    completionMode: null,
    movementAdvice: "身体站直，双脚交替抬起。",
    intensityAdvice: "呼吸稍快，但仍能完整说话。",
    localDay: "2026-07-22",
    clientUpdatedAt: "2026-07-22T09:00:00.000Z"
  };
}

async function putAction(
  baseURL: string,
  id: string,
  token: string,
  body: Record<string, unknown>
) {
  const response = await fetch(`${baseURL}/exercise-actions/${id}`, {
    method: "PUT",
    headers: {
      ...authHeaders(token),
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });
  return { response, body: await response.json() as any };
}

async function getActions(baseURL: string, token: string, localDay: string) {
  const response = await fetch(`${baseURL}/exercise-actions?localDay=${localDay}`, {
    headers: authHeaders(token)
  });
  return { response, body: await response.json() as any };
}

function cloneInput(input: ExerciseActionWriteInput): ExerciseActionWriteInput {
  return {
    ...input,
    contexts: [...input.contexts],
    scheduledStartAt: new Date(input.scheduledStartAt),
    completedAt: input.completedAt ? new Date(input.completedAt) : null,
    actualStartedAt: input.actualStartedAt ? new Date(input.actualStartedAt) : null,
    timerLastResumedAt: input.timerLastResumedAt ? new Date(input.timerLastResumedAt) : null,
    actualEndedAt: input.actualEndedAt ? new Date(input.actualEndedAt) : null,
    clientUpdatedAt: new Date(input.clientUpdatedAt)
  };
}

function cloneRecord(record: ExerciseActionRecord): ExerciseActionRecord {
  return {
    ...cloneInput(record),
    id: record.id,
    userId: record.userId,
    createdAt: new Date(record.createdAt),
    updatedAt: new Date(record.updatedAt),
    deletedAt: record.deletedAt ? new Date(record.deletedAt) : null
  };
}
