import assert from "node:assert/strict";
import test from "node:test";
import {
  deriveResearchActionChanges,
  type ResearchActionItem
} from "./researchActionRoutes.js";

const firstID = "11111111-1111-4111-8111-111111111111";
const secondID = "22222222-2222-4222-8222-222222222222";

test("research snapshot diff preserves creation, completion, rescheduling and deletion", () => {
  const original = makeItem(firstID);
  const created = makeItem(secondID, { title: "午餐建议", type: "diet" });
  assert.deepEqual(
    deriveResearchActionChanges([], [original]).map((change) => change.eventType),
    ["created"]
  );

  const completed = makeItem(firstID, {
    status: "completed",
    effectiveStatus: "completed",
    completedAt: "2026-08-13T09:15:00.000Z",
    clientUpdatedAt: "2026-08-13T09:15:00.000Z"
  });
  assert.equal(deriveResearchActionChanges([original], [completed])[0]?.eventType, "status_changed");

  const rescheduled = makeItem(firstID, {
    scheduledStartAt: "2026-08-13T10:00:00.000Z",
    scheduledEndAt: "2026-08-13T10:15:00.000Z",
    clientUpdatedAt: "2026-08-13T09:30:00.000Z"
  });
  assert.equal(deriveResearchActionChanges([original], [rescheduled])[0]?.eventType, "rescheduled");

  const mixed = deriveResearchActionChanges([original], [created]);
  assert.deepEqual(mixed.map((change) => change.eventType), ["deleted", "created"]);
  assert.equal(mixed[0]?.beforeState?.title, "原地踏步");
  assert.equal(mixed[1]?.afterState?.title, "午餐建议");
});

test("identical research snapshots do not create duplicate events", () => {
  const item = makeItem(firstID);
  assert.deepEqual(deriveResearchActionChanges([item], [{ ...item }]), []);
});

function makeItem(
  id: string,
  overrides: Partial<ResearchActionItem> = {}
): ResearchActionItem {
  return {
    id,
    type: "walk",
    title: "原地踏步",
    description: "轻量活动",
    reason: "根据当前状态推荐",
    scheduledStartAt: "2026-08-13T09:00:00.000Z",
    scheduledEndAt: "2026-08-13T09:15:00.000Z",
    durationMinutes: 15,
    status: "pending",
    effectiveStatus: "pending",
    completedAt: null,
    sortOrder: 0,
    bloodPressureText: null,
    adviceText: null,
    exerciseId: "march-in-place",
    exerciseScene: "私人室内",
    exerciseEnergy: "精力一般",
    exerciseContexts: ["久坐后"],
    exerciseMovementAdvice: "自然踏步。",
    exerciseIntensityAdvice: "保持舒适节奏。",
    actualStartedAt: null,
    actualEndedAt: null,
    actualDurationSeconds: null,
    completionMode: null,
    clientUpdatedAt: "2026-08-13T09:00:00.000Z",
    ...overrides
  };
}
