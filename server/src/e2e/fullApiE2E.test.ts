import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import test from "node:test";
import type { ServerConfig } from "../config.js";
import { createApp } from "../app.js";
import { prisma } from "../db/prisma.js";
import type { MealAnalysisContext } from "../domain/mealAnalysis.js";
import type { MealAnalysisService } from "../services/openAIMealAnalysisService.js";
import { MockBPRecognitionService } from "../services/bpRecognitionService.js";

const shouldRun = process.env.RUN_BPHEALTH_E2E === "1";
const jpegBase64 = "/9j/4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP/Z";

test("real registration and PostgreSQL API lifecycle", { skip: !shouldRun }, async () => {
  assertSafeE2EDatabase(process.env.DATABASE_URL);

  const suffix = randomUUID();
  const primaryEmail = `bphealth-e2e-${suffix}@example.com`;
  const secondaryEmail = `bphealth-e2e-other-${suffix}@example.com`;
  const concurrentEmail = `bphealth-e2e-race-${suffix}@example.com`;
  const password = "E2E-real-password-2026!";
  const wrongPassword = "E2E-wrong-password-2026!";
  const analysisContexts: MealAnalysisContext[] = [];
  let analysisCount = 0;
  const mealAnalysisService: MealAnalysisService = {
    async analyze(image, context) {
      analysisCount += 1;
      analysisContexts.push(context);
      assert.equal(image.mimeType, "image/jpeg");
      assert.equal(image.base64, jpegBase64);
      return {
        canAnalyze: true,
        recognition: `第${analysisCount}次识别：照片中可见主食、蔬菜和蛋白质食物。`,
        dietaryStructureAnalysis: "餐食包含碳水化合物、膳食纤维和蛋白质，搭配较完整。",
        cookingMethodAnalysis: "照片看起来以清炒和蒸煮为主。",
        dietaryStructureSuggestion: "下次可适量增加蔬菜，并选择较少加工的蛋白质。",
        cookingMethodSuggestion: "下次可少放盐和酱汁，优先清蒸或少油烹调。",
        cardSummary: `第${analysisCount}次：搭配较丰富，可减少酱汁。`
      };
    }
  };
  const config: ServerConfig = {
    port: 0,
    recognitionMode: "openai",
    openAIModel: "e2e-recognition-model",
    openAIActionSuggestionModel: "e2e-action-model",
    openAIMealAnalysisModel: "e2e-meal-model",
    bpRecognitionDailyLimit: 2,
    mealAnalysisDailyLimit: 3,
    minimumSupportedIOSBuild: 0,
    iosUpdateURL: "https://testflight.apple.com/join/TyhR9xzw",
    accessTokenSecret: "bphealth-e2e-access-token-secret-with-enough-entropy",
    accessTokenTTLSeconds: 900,
    refreshTokenTTLDays: 30,
    emailVerificationTTLHours: 24,
    emailVerificationBaseURL: "http://localhost/auth/verify-email"
  };
  const app = createApp(config, {
    mealAnalysisService,
    recognitionService: new MockBPRecognitionService()
  });
  const server = app.listen(0, "127.0.0.1");

  let primaryAccessToken = "";
  let primaryRefreshToken = "";
  let secondaryAccessToken = "";
  let primaryUserId = "";
  let secondaryUserId = "";
  let concurrentUserId = "";
  let reregisteredUserId = "";

  try {
    await waitForListening(server);
    const address = server.address() as AddressInfo;
    const baseURL = `http://127.0.0.1:${address.port}`;

    const unauthenticatedProfile = await fetch(`${baseURL}/profile`);
    assert.equal(unauthenticatedProfile.status, 401);

    const registration = await requestJSON(baseURL, "/auth/register", {
      method: "POST",
      body: { email: primaryEmail, password, deviceId: "e2e-primary-device" }
    });
    assert.equal(registration.response.status, 201);
    assert.equal(registration.body.user.email, primaryEmail);
    assert.equal(registration.body.user.emailVerified, true);
    assert.equal(registration.body.user.profileCompleted, false);
    assert.equal(typeof registration.body.accessToken, "string");
    assert.equal(typeof registration.body.refreshToken, "string");
    primaryUserId = registration.body.user.id;

    const duplicateRegistration = await requestJSON(baseURL, "/auth/register", {
      method: "POST",
      body: { email: primaryEmail.toUpperCase(), password }
    });
    assert.equal(duplicateRegistration.response.status, 409);
    assert.equal(duplicateRegistration.body.code, "EMAIL_ALREADY_REGISTERED");

    const concurrentRegistrations = await Promise.all([
      requestJSON(baseURL, "/auth/register", {
        method: "POST",
        body: { email: concurrentEmail, password, deviceId: "e2e-race-a" }
      }),
      requestJSON(baseURL, "/auth/register", {
        method: "POST",
        body: { email: concurrentEmail, password, deviceId: "e2e-race-b" }
      })
    ]);
    assert.deepEqual(
      concurrentRegistrations.map((result) => result.response.status).sort(),
      [201, 409]
    );
    const concurrentWinner = concurrentRegistrations.find((result) => result.response.status === 201);
    assert.ok(concurrentWinner);
    concurrentUserId = concurrentWinner.body.user.id;
    const deleteConcurrentWinner = await fetch(`${baseURL}/auth/account`, {
      method: "DELETE",
      headers: authHeaders(concurrentWinner.body.accessToken),
      body: JSON.stringify({ password })
    });
    assert.equal(deleteConcurrentWinner.status, 204);

    const wrongLogin = await requestJSON(baseURL, "/auth/login", {
      method: "POST",
      body: { email: primaryEmail, password: wrongPassword }
    });
    assert.equal(wrongLogin.response.status, 401);
    assert.equal(wrongLogin.body.code, "INVALID_CREDENTIALS");

    const login = await requestJSON(baseURL, "/auth/login", {
      method: "POST",
      body: { email: primaryEmail, password, deviceId: "e2e-login-device" }
    });
    assert.equal(login.response.status, 200);
    assert.equal(login.body.user.id, primaryUserId);

    const me = await requestJSON(baseURL, "/auth/me", {
      headers: authHeaders(login.body.accessToken)
    });
    assert.equal(me.response.status, 200);
    assert.equal(me.body.user.email, primaryEmail);

    const refreshed = await requestJSON(baseURL, "/auth/refresh", {
      method: "POST",
      body: { refreshToken: login.body.refreshToken, deviceId: "e2e-refreshed-device" }
    });
    assert.equal(refreshed.response.status, 200);
    assert.notEqual(refreshed.body.refreshToken, login.body.refreshToken);
    primaryAccessToken = refreshed.body.accessToken;
    primaryRefreshToken = refreshed.body.refreshToken;

    const replayedRefresh = await requestJSON(baseURL, "/auth/refresh", {
      method: "POST",
      body: { refreshToken: login.body.refreshToken }
    });
    assert.equal(replayedRefresh.response.status, 401);
    assert.equal(replayedRefresh.body.code, "INVALID_REFRESH_TOKEN");

    const logoutResponse = await fetch(`${baseURL}/auth/logout`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: refreshed.body.refreshToken })
    });
    assert.equal(logoutResponse.status, 204);

    const loggedOutRefresh = await requestJSON(baseURL, "/auth/refresh", {
      method: "POST",
      body: { refreshToken: refreshed.body.refreshToken }
    });
    assert.equal(loggedOutRefresh.response.status, 401);

    const emptyProfile = await requestJSON(baseURL, "/profile", {
      headers: authHeaders(primaryAccessToken)
    });
    assert.equal(emptyProfile.response.status, 200);
    assert.equal(emptyProfile.body.profile, null);

    const profileUpdate = await requestJSON(baseURL, "/profile", {
      method: "PUT",
      headers: authHeaders(primaryAccessToken),
      body: {
        displayName: "E2E 用户",
        birthYear: 1990,
        sex: "prefer_not_to_say",
        heightCm: 172.5,
        weightKg: 68.2,
        todaySteps: 6234,
        exerciseMinutes: 25,
        restingHeartRate: 63,
        sleepHours: 7.2,
        healthDataSource: "healthkit",
        healthDataSyncedAt: "2026-07-21T08:00:00.000Z"
      }
    });
    assert.equal(profileUpdate.response.status, 200);
    assert.equal(profileUpdate.body.profile.todaySteps, 6234);
    assert.equal(profileUpdate.body.profile.heightCm, 172.5);

    const loadedProfile = await requestJSON(baseURL, "/profile", {
      headers: authHeaders(primaryAccessToken)
    });
    assert.equal(loadedProfile.response.status, 200);
    assert.equal(loadedProfile.body.profile.displayName, "E2E 用户");

    const unauthenticatedRecognition = await requestJSON(baseURL, "/recognize-bp", {
      method: "POST",
      body: {}
    });
    assert.equal(unauthenticatedRecognition.response.status, 401);

    const invalidRecognitionImage = await requestJSON(baseURL, "/recognize-bp", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: { imageBase64: "abcdefghijklmnopqrstuvwxyz1234567890" }
    });
    assert.equal(invalidRecognitionImage.response.status, 400);
    assert.equal(invalidRecognitionImage.body.code, "BAD_REQUEST");

    const concurrentRecognitions = await Promise.all(Array.from({ length: 3 }, () => (
      requestJSON(baseURL, "/recognize-bp", {
        method: "POST",
        headers: authHeaders(primaryAccessToken),
        body: { imageBase64: `data:image/jpeg;base64,${jpegBase64}` }
      })
    )));
    assert.deepEqual(
      concurrentRecognitions.map((result) => result.response.status).sort(),
      [200, 200, 429]
    );
    assert.ok(concurrentRecognitions
      .filter((result) => result.response.status === 200)
      .every((result) => result.body.systolic === 128));
    assert.equal(
      concurrentRecognitions.find((result) => result.response.status === 429)?.body.code,
      "AI_DAILY_QUOTA_EXCEEDED"
    );

    const clientId = randomUUID();
    const createReading = await requestJSON(baseURL, "/readings", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: {
        clientId,
        systolic: 128,
        diastolic: 82,
        pulse: 71,
        measuredAt: "2026-07-21T07:45:00.000Z",
        source: "manual",
        note: "E2E initial reading"
      }
    });
    assert.equal(createReading.response.status, 201);
    const readingId = createReading.body.reading.id;

    const invalidPartialUpdate = await requestJSON(baseURL, `/readings/${readingId}`, {
      method: "PUT",
      headers: authHeaders(primaryAccessToken),
      body: { diastolic: 140 }
    });
    assert.equal(invalidPartialUpdate.response.status, 400);
    assert.equal(invalidPartialUpdate.body.code, "INVALID_READING_VALUES");

    const validReadingUpdate = await requestJSON(baseURL, `/readings/${readingId}`, {
      method: "PUT",
      headers: authHeaders(primaryAccessToken),
      body: { systolic: 130, diastolic: 84, note: "E2E updated reading" }
    });
    assert.equal(validReadingUpdate.response.status, 200);
    assert.equal(validReadingUpdate.body.reading.systolic, 130);
    assert.equal(validReadingUpdate.body.reading.diastolic, 84);

    const secondaryRegistration = await requestJSON(baseURL, "/auth/register", {
      method: "POST",
      body: { email: secondaryEmail, password, deviceId: "e2e-secondary-device" }
    });
    assert.equal(secondaryRegistration.response.status, 201);
    secondaryAccessToken = secondaryRegistration.body.accessToken;
    secondaryUserId = secondaryRegistration.body.user.id;

    const exerciseActionId = randomUUID();
    const createdExerciseAction = await requestJSON(baseURL, `/exercise-actions/${exerciseActionId}`, {
      method: "PUT",
      headers: authHeaders(primaryAccessToken),
      body: exerciseActionPayload("原地踏步", "2026-07-21T15:00:00.000Z")
    });
    assert.equal(createdExerciseAction.response.status, 200);
    assert.equal(createdExerciseAction.body.applied, true);
    assert.equal(createdExerciseAction.body.action.id, exerciseActionId);

    const staleExerciseAction = await requestJSON(baseURL, `/exercise-actions/${exerciseActionId}`, {
      method: "PUT",
      headers: authHeaders(primaryAccessToken),
      body: exerciseActionPayload("不应覆盖的新名称", "2026-07-21T14:59:59.000Z")
    });
    assert.equal(staleExerciseAction.response.status, 200);
    assert.equal(staleExerciseAction.body.applied, false);
    assert.equal(staleExerciseAction.body.action.title, "原地踏步");

    const crossUserExerciseAction = await requestJSON(baseURL, `/exercise-actions/${exerciseActionId}`, {
      method: "PUT",
      headers: authHeaders(secondaryAccessToken),
      body: exerciseActionPayload("试图覆盖", "2026-07-21T16:00:00.000Z")
    });
    assert.equal(crossUserExerciseAction.response.status, 409);
    assert.equal(crossUserExerciseAction.body.code, "EXERCISE_ACTION_ID_CONFLICT");

    const primaryExerciseActions = await requestJSON(
      baseURL,
      "/exercise-actions?localDay=2026-07-21",
      { headers: authHeaders(primaryAccessToken) }
    );
    assert.equal(primaryExerciseActions.response.status, 200);
    assert.equal(primaryExerciseActions.body.actions.length, 1);
    assert.equal(primaryExerciseActions.body.actions[0].clientUpdatedAt, "2026-07-21T15:00:00.000Z");

    const secondaryExerciseActions = await requestJSON(
      baseURL,
      "/exercise-actions?localDay=2026-07-21",
      { headers: authHeaders(secondaryAccessToken) }
    );
    assert.deepEqual(secondaryExerciseActions.body.actions, []);

    const crossUserReadingUpdate = await requestJSON(baseURL, `/readings/${readingId}`, {
      method: "PUT",
      headers: authHeaders(secondaryAccessToken),
      body: { systolic: 132 }
    });
    assert.equal(crossUserReadingUpdate.response.status, 404);
    assert.equal(crossUserReadingUpdate.body.code, "READING_NOT_FOUND");

    const syncedClientId = randomUUID();
    const sync = await requestJSON(baseURL, "/sync/readings", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: {
        readings: [
          {
            clientId,
            systolic: 131,
            diastolic: 83,
            pulse: 70,
            measuredAt: "2026-07-21T07:45:00.000Z",
            source: "manual",
            note: "E2E idempotent sync"
          },
          {
            clientId: syncedClientId,
            systolic: 124,
            diastolic: 79,
            pulse: 68,
            measuredAt: "2026-07-21T20:30:00.000Z",
            source: "health_import",
            note: null
          }
        ]
      }
    });
    assert.equal(sync.response.status, 200);
    assert.equal(sync.body.readings.length, 2);
    assert.equal(sync.body.readings[0].id, readingId);

    const listedReadings = await requestJSON(baseURL, "/readings?limit=10", {
      headers: authHeaders(primaryAccessToken)
    });
    assert.equal(listedReadings.response.status, 200);
    assert.equal(listedReadings.body.readings.length, 2);
    assert.equal(listedReadings.body.readings[0].clientId, syncedClientId);

    const interpretation = await requestJSON(baseURL, "/readings/interpretation", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: {
        systolicBp: 131,
        diastolicBp: 83,
        bpMonitorPulse: 70,
        measurementTime: "2026-07-21T20:30:00.000Z",
        recentBpReadings: [{
          systolicBp: 130,
          diastolicBp: 84,
          measurementTime: "2026-07-21T07:45:00.000Z"
        }]
      }
    });
    assert.equal(interpretation.response.status, 200);
    assert.equal(interpretation.body.interpretation.category, "borderline");
    assert.equal(typeof interpretation.body.interpretation.summary, "string");

    const deleteReadingResponse = await fetch(`${baseURL}/readings/${readingId}`, {
      method: "DELETE",
      headers: authHeaders(primaryAccessToken)
    });
    assert.equal(deleteReadingResponse.status, 204);

    const activeReadings = await requestJSON(baseURL, "/readings?limit=10", {
      headers: authHeaders(primaryAccessToken)
    });
    assert.equal(activeReadings.body.readings.length, 1);

    const allReadings = await requestJSON(baseURL, "/readings?limit=10&includeDeleted=true", {
      headers: authHeaders(primaryAccessToken)
    });
    assert.equal(allReadings.body.readings.length, 2);
    assert.ok(allReadings.body.readings.some((reading: { id: string; deletedAt: string | null }) => (
      reading.id === readingId && reading.deletedAt !== null
    )));

    const updateDeletedReading = await requestJSON(baseURL, `/readings/${readingId}`, {
      method: "PUT",
      headers: authHeaders(primaryAccessToken),
      body: { systolic: 129 }
    });
    assert.equal(updateDeletedReading.response.status, 404);

    const invalidMealDate = await requestJSON(baseURL, "/meal-records/analyze", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: mealPayload("lunch", "2026-02-30", "2026-07-21T12:30:00.000Z")
    });
    assert.equal(invalidMealDate.response.status, 400);
    assert.equal(invalidMealDate.body.code, "VALIDATION_FAILED");

    const invalidMealImage = await requestJSON(baseURL, "/meal-records/analyze", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: {
        ...mealPayload("lunch", "2026-07-21", "2026-07-21T12:30:00.000Z"),
        imageBase64: "data:image/jpeg;base64,abcdefghijklmnopqrstuvwxyz1234567890"
      }
    });
    assert.equal(invalidMealImage.response.status, 400);

    const firstMeal = await requestJSON(baseURL, "/meal-records/analyze", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: mealPayload("lunch", "2026-07-21", "2026-07-21T12:30:00.000Z")
    });
    assert.equal(firstMeal.response.status, 200);
    assert.equal(firstMeal.body.source, "openai");
    const firstMealId = firstMeal.body.record.id;
    const firstMealCreatedAt = firstMeal.body.record.createdAt;

    const updatedMeal = await requestJSON(baseURL, "/meal-records/analyze", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: mealPayload("lunch", "2026-07-21", "2026-07-21T13:00:00.000Z")
    });
    assert.equal(updatedMeal.response.status, 200);
    assert.equal(updatedMeal.body.record.id, firstMealId);
    assert.equal(updatedMeal.body.record.createdAt, firstMealCreatedAt);
    assert.match(updatedMeal.body.record.recognition, /第2次识别/);
    assert.match(updatedMeal.body.record.analysis, /饮食结构/);

    const dinnerMeal = await requestJSON(baseURL, "/meal-records/analyze", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: mealPayload("dinner", "2026-07-21", "2026-07-21T18:30:00.000Z")
    });
    assert.equal(dinnerMeal.response.status, 200);

    const primaryMeals = await requestJSON(baseURL, "/meal-records?date=2026-07-21", {
      headers: authHeaders(primaryAccessToken)
    });
    assert.equal(primaryMeals.response.status, 200);
    assert.equal(primaryMeals.body.records.length, 2);
    assert.deepEqual(primaryMeals.body.records.map((record: { mealType: string }) => record.mealType), ["lunch", "dinner"]);
    assert.ok(primaryMeals.body.records.every((record: Record<string, unknown>) => !("imageBase64" in record)));

    const secondaryMealsBefore = await requestJSON(baseURL, "/meal-records?date=2026-07-21", {
      headers: authHeaders(secondaryAccessToken)
    });
    assert.deepEqual(secondaryMealsBefore.body.records, []);

    const secondaryMeal = await requestJSON(baseURL, "/meal-records/analyze", {
      method: "POST",
      headers: authHeaders(secondaryAccessToken),
      body: mealPayload("lunch", "2026-07-21", "2026-07-21T12:45:00.000Z")
    });
    assert.equal(secondaryMeal.response.status, 200);
    assert.notEqual(secondaryMeal.body.record.id, firstMealId);

    const exhaustedMealQuota = await requestJSON(baseURL, "/meal-records/analyze", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: mealPayload("breakfast", "2026-07-21", "2026-07-21T08:00:00.000Z")
    });
    assert.equal(exhaustedMealQuota.response.status, 429);
    assert.equal(exhaustedMealQuota.body.code, "AI_DAILY_QUOTA_EXCEEDED");

    assert.equal(await prisma.mealRecord.count({
      where: { userId: primaryUserId, mealDate: "2026-07-21", mealType: "lunch" }
    }), 1);
    await assert.rejects(prisma.mealRecord.create({
      data: {
        userId: primaryUserId,
        mealType: "breakfast",
        mealDate: "2026-02-30",
        analysis: "invalid date fixture",
        similarSuggestion: "invalid date fixture",
        cardSummary: "invalid date fixture",
        recordedAt: new Date("2026-02-28T08:00:00.000Z")
      }
    }));
    assert.equal(analysisContexts.length, 4);
    assert.equal(analysisContexts[0]?.profile.todaySteps, 6234);
    assert.ok((analysisContexts[0]?.recentBloodPressureReadings.length ?? 0) >= 1);

    const unauthenticatedActionSuggestions = await requestJSON(baseURL, "/action-adjustments/trend-suggestions", {
      method: "POST",
      body: actionSuggestionPayload()
    });
    assert.equal(unauthenticatedActionSuggestions.response.status, 401);

    const actionSuggestions = await requestJSON(baseURL, "/action-adjustments/trend-suggestions", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: actionSuggestionPayload()
    });
    assert.equal(actionSuggestions.response.status, 200);
    assert.equal(actionSuggestions.body.source, "rule_based");
    assert.equal(actionSuggestions.body.evidenceDays, 1);
    assert.ok(actionSuggestions.body.suggestions.length > 0);
    assert.ok(actionSuggestions.body.suggestions.every((suggestion: { targetActionId: string }) => (
      suggestion.targetActionId === "44444444-4444-4444-8444-444444444444"
    )));
    assert.ok(actionSuggestions.body.suggestions.every((suggestion: { message: string }) => (
      !/最近|经常|完成率|趋势/.test(suggestion.message)
    )));

    const researchActionId = randomUUID();
    const initialResearchSync = await requestJSON(baseURL, "/research-actions/sync", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: researchSnapshotPayload(researchActionId, "pending", "2026-07-21T15:00:00.000Z")
    });
    assert.equal(initialResearchSync.response.status, 200, JSON.stringify(initialResearchSync.body));
    assert.equal(initialResearchSync.body.applied, true);
    assert.equal(initialResearchSync.body.eventCount, 1);

    const completedResearchSync = await requestJSON(baseURL, "/research-actions/sync", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: researchSnapshotPayload(researchActionId, "completed", "2026-07-21T15:15:00.000Z")
    });
    assert.equal(completedResearchSync.response.status, 200);
    assert.equal(completedResearchSync.body.version, 2);
    assert.equal(completedResearchSync.body.eventCount, 1);

    const researchDays = await requestJSON(
      baseURL,
      "/research-actions/days?from=2026-07-21&to=2026-07-21",
      { headers: authHeaders(primaryAccessToken) }
    );
    assert.equal(researchDays.response.status, 200);
    assert.equal(researchDays.body.snapshots.length, 1);
    assert.equal(researchDays.body.snapshots[0].completedCount, 1);
    assert.equal(researchDays.body.snapshots[0].items[0].status, "completed");
    assert.equal(await prisma.actionEvent.count({ where: { userId: primaryUserId } }), 2);

    const invalidActionSuggestions = await requestJSON(baseURL, "/action-adjustments/trend-suggestions", {
      method: "POST",
      headers: authHeaders(primaryAccessToken),
      body: { ...actionSuggestionPayload(), unexpected: true }
    });
    assert.equal(invalidActionSuggestions.response.status, 400);
    assert.equal(invalidActionSuggestions.body.code, "VALIDATION_FAILED");

    const wrongDeletePassword = await requestJSON(baseURL, "/auth/account", {
      method: "DELETE",
      headers: authHeaders(primaryAccessToken),
      body: { password: wrongPassword }
    });
    assert.equal(wrongDeletePassword.response.status, 403);
    assert.equal(wrongDeletePassword.body.code, "PASSWORD_CONFIRMATION_FAILED");

    const retainedCountsBeforeDeletion = {
      profiles: await prisma.userProfile.count({ where: { userId: primaryUserId } }),
      readings: await prisma.bloodPressureReading.count({ where: { userId: primaryUserId } }),
      meals: await prisma.mealRecord.count({ where: { userId: primaryUserId } }),
      exercises: await prisma.exerciseAction.count({ where: { userId: primaryUserId } }),
      aiUsage: await prisma.aIDailyUsage.count({ where: { userId: primaryUserId } }),
      actionSnapshots: await prisma.dailyActionSnapshot.count({ where: { userId: primaryUserId } }),
      actionEvents: await prisma.actionEvent.count({ where: { userId: primaryUserId } })
    };

    const deletePrimaryResponse = await fetch(`${baseURL}/auth/account`, {
      method: "DELETE",
      headers: authHeaders(primaryAccessToken),
      body: JSON.stringify({ password })
    });
    assert.equal(deletePrimaryResponse.status, 204);
    assert.deepEqual({
      profiles: await prisma.userProfile.count({ where: { userId: primaryUserId } }),
      readings: await prisma.bloodPressureReading.count({ where: { userId: primaryUserId } }),
      meals: await prisma.mealRecord.count({ where: { userId: primaryUserId } }),
      exercises: await prisma.exerciseAction.count({ where: { userId: primaryUserId } }),
      aiUsage: await prisma.aIDailyUsage.count({ where: { userId: primaryUserId } }),
      actionSnapshots: await prisma.dailyActionSnapshot.count({ where: { userId: primaryUserId } }),
      actionEvents: await prisma.actionEvent.count({ where: { userId: primaryUserId } })
    }, retainedCountsBeforeDeletion);
    const retainedUser = await prisma.user.findUniqueOrThrow({
      where: { id: primaryUserId },
      include: { profile: true }
    });
    assert.ok(retainedUser.deletedAt);
    assert.equal(retainedUser.researchEmail, primaryEmail);
    assert.notEqual(retainedUser.email, primaryEmail);
    assert.match(retainedUser.email, /^deleted\+.+@accounts\.bphealth\.invalid$/);
    assert.match(retainedUser.profile?.displayName ?? "", /^研究参与者-/);

    const deletedUserMe = await requestJSON(baseURL, "/auth/me", {
      headers: authHeaders(primaryAccessToken)
    });
    assert.equal(deletedUserMe.response.status, 401);

    const deletedUserRefresh = await requestJSON(baseURL, "/auth/refresh", {
      method: "POST",
      body: { refreshToken: primaryRefreshToken }
    });
    assert.equal(deletedUserRefresh.response.status, 401);
    assert.equal(deletedUserRefresh.body.code, "INVALID_REFRESH_TOKEN");

    const deletedUserLogin = await requestJSON(baseURL, "/auth/login", {
      method: "POST",
      body: { email: primaryEmail, password }
    });
    assert.equal(deletedUserLogin.response.status, 401);
    assert.equal(deletedUserLogin.body.code, "INVALID_CREDENTIALS");

    const registrationAfterDeletion = await requestJSON(baseURL, "/auth/register", {
      method: "POST",
      body: { email: primaryEmail, password, deviceId: "e2e-reregistered-device" }
    });
    assert.equal(registrationAfterDeletion.response.status, 201);
    reregisteredUserId = registrationAfterDeletion.body.user.id;
    assert.notEqual(reregisteredUserId, primaryUserId);

    const deletedUserProtectedRequests = await Promise.all([
      requestJSON(baseURL, "/profile", { headers: authHeaders(primaryAccessToken) }),
      requestJSON(baseURL, "/readings", { headers: authHeaders(primaryAccessToken) }),
      requestJSON(baseURL, "/meal-records?date=2026-07-21", { headers: authHeaders(primaryAccessToken) }),
      requestJSON(baseURL, "/exercise-actions?localDay=2026-07-21", { headers: authHeaders(primaryAccessToken) }),
      requestJSON(baseURL, "/action-adjustments/trend-suggestions", {
        method: "POST",
        headers: authHeaders(primaryAccessToken),
        body: actionSuggestionPayload()
      }),
      requestJSON(baseURL, "/recognize-bp", {
        method: "POST",
        headers: authHeaders(primaryAccessToken),
        body: { imageBase64: `data:image/jpeg;base64,${jpegBase64}` }
      })
    ]);
    assert.ok(deletedUserProtectedRequests.every((result) => result.response.status === 401));

    const deleteSecondaryResponse = await fetch(`${baseURL}/auth/account`, {
      method: "DELETE",
      headers: authHeaders(secondaryAccessToken),
      body: JSON.stringify({ password })
    });
    assert.equal(deleteSecondaryResponse.status, 204);
    assert.equal(await prisma.user.count({ where: { id: secondaryUserId, deletedAt: { not: null } } }), 1);
  } finally {
    if (server.listening) {
      await new Promise<void>((resolve, reject) => {
        server.close((error) => error ? reject(error) : resolve());
      });
    }
    const testUserIds = [primaryUserId, secondaryUserId, concurrentUserId, reregisteredUserId].filter(Boolean);
    await prisma.user.deleteMany({ where: { id: { in: testUserIds } } });
    await prisma.user.deleteMany({ where: { email: { in: [primaryEmail, secondaryEmail, concurrentEmail] } } });
    await prisma.$disconnect();
  }
});

function authHeaders(accessToken: string): Record<string, string> {
  return {
    Authorization: `Bearer ${accessToken}`,
    "Content-Type": "application/json"
  };
}

async function requestJSON(
  baseURL: string,
  path: string,
  options: {
    method?: string;
    headers?: Record<string, string>;
    body?: unknown;
  } = {}
): Promise<{ response: Response; body: any }> {
  const response = await fetch(`${baseURL}${path}`, {
    method: options.method ?? "GET",
    headers: {
      ...(options.body === undefined ? {} : { "Content-Type": "application/json" }),
      ...options.headers
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body)
  });
  const text = await response.text();
  return {
    response,
    body: text ? JSON.parse(text) : null
  };
}

function mealPayload(mealType: string, mealDate: string, recordedAt: string) {
  return {
    mealType,
    mealDate,
    recordedAt,
    timeZone: "Europe/London",
    imageBase64: `data:image/jpeg;base64,${jpegBase64}`
  };
}

function actionSuggestionPayload() {
  return {
    now: "2026-07-21T18:00:00.000Z",
    timeZone: "Europe/London",
    todayActions: [
      {
        id: "44444444-4444-4444-8444-444444444444",
        type: "exercise",
        title: "原地踏步",
        scheduledStartAt: "2026-07-21T15:00:00.000Z",
        durationMinutes: 20,
        status: "missed",
        completedAt: null
      },
      {
        id: "55555555-5555-4555-8555-555555555555",
        type: "diet",
        title: "晚餐建议",
        scheduledStartAt: "2026-07-21T18:30:00.000Z",
        durationMinutes: 20,
        status: "completed",
        completedAt: "2026-07-21T18:50:00.000Z"
      }
    ],
    recentActions: []
  };
}

function exerciseActionPayload(title: string, clientUpdatedAt: string) {
  return {
    exerciseId: "indoor-in-place-march",
    title,
    scene: "室内居家",
    energy: "精力一般",
    contexts: ["久坐后"],
    scheduledStartAt: "2026-07-21T15:00:00.000Z",
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
    localDay: "2026-07-21",
    clientUpdatedAt
  };
}

function researchSnapshotPayload(
  itemId: string,
  status: "pending" | "completed",
  capturedAt: string
) {
  const completed = status === "completed";
  return {
    localDay: "2026-07-21",
    timeZone: "Europe/London",
    capturedAt,
    items: [{
      id: itemId,
      type: "walk",
      title: "原地踏步",
      description: "完成今天的低门槛运动。",
      reason: "久坐后轻量活动。",
      scheduledStartAt: "2026-07-21T15:00:00.000Z",
      scheduledEndAt: "2026-07-21T15:10:00.000Z",
      durationMinutes: 10,
      status,
      effectiveStatus: status,
      completedAt: completed ? "2026-07-21T15:10:00.000Z" : null,
      sortOrder: 0,
      bloodPressureText: null,
      adviceText: null,
      exerciseId: "indoor-in-place-march",
      exerciseScene: "私人室内",
      exerciseEnergy: "精力一般",
      exerciseContexts: ["久坐后"],
      exerciseMovementAdvice: "身体站直，双脚交替抬起。",
      exerciseIntensityAdvice: "呼吸稍快，但仍能完整说话。",
      actualStartedAt: completed ? "2026-07-21T15:00:00.000Z" : null,
      actualEndedAt: completed ? "2026-07-21T15:10:00.000Z" : null,
      actualDurationSeconds: completed ? 600 : null,
      completionMode: completed ? "timer_completed" : null,
      clientUpdatedAt: capturedAt
    }]
  };
}

function assertSafeE2EDatabase(value: string | undefined): void {
  assert.ok(value, "DATABASE_URL is required for E2E tests.");
  const url = new URL(value);
  assert.ok(["127.0.0.1", "localhost", "::1"].includes(url.hostname), "E2E database must be local.");
  assert.match(url.pathname.toLowerCase(), /e2e/, "E2E database name must contain 'e2e'.");
}

async function waitForListening(server: Server): Promise<void> {
  if (server.listening) {
    return;
  }
  await new Promise<void>((resolve, reject) => {
    server.once("listening", resolve);
    server.once("error", reject);
  });
}
