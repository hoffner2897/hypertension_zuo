import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import test from "node:test";

const shouldRun = process.env.RUN_BPHEALTH_STAGING_E2E === "1";

test("staging API lifecycle through real registration", { skip: !shouldRun }, async () => {
  const baseURL = process.env.BPHEALTH_STAGING_URL ?? "https://bphealth-api-staging.onrender.com";
  assertSafeStagingURL(baseURL);

  const suffix = randomUUID();
  const email = `bphealth-staging-e2e-${suffix}@example.com`;
  const password = "Staging-E2E-real-password-2026!";
  const wrongPassword = "Staging-E2E-wrong-password-2026!";
  let accessToken = "";
  const featureFailures: string[] = [];

  try {
    const health = await requestJSON(baseURL, "/health");
    assert.equal(health.response.status, 200);
    assert.equal(health.body.ok, true);

    const registration = await requestJSON(baseURL, "/auth/register", {
      method: "POST",
      body: { email, password, deviceId: `staging-e2e-${suffix}` }
    });
    assert.equal(registration.response.status, 201);
    assert.equal(registration.body.user.email, email);
    assert.equal(registration.body.user.emailVerified, true);
    accessToken = registration.body.accessToken;

    const duplicate = await requestJSON(baseURL, "/auth/register", {
      method: "POST",
      body: { email: email.toUpperCase(), password }
    });
    assert.equal(duplicate.response.status, 409);
    assert.equal(duplicate.body.code, "EMAIL_ALREADY_REGISTERED");

    const wrongLogin = await requestJSON(baseURL, "/auth/login", {
      method: "POST",
      body: { email, password: wrongPassword }
    });
    assert.equal(wrongLogin.response.status, 401);
    assert.equal(wrongLogin.body.code, "INVALID_CREDENTIALS");

    const login = await requestJSON(baseURL, "/auth/login", {
      method: "POST",
      body: { email, password, deviceId: `staging-login-${suffix}` }
    });
    assert.equal(login.response.status, 200);

    const me = await requestJSON(baseURL, "/auth/me", {
      headers: authHeaders(login.body.accessToken)
    });
    assert.equal(me.response.status, 200);
    assert.equal(me.body.user.email, email);

    const refreshed = await requestJSON(baseURL, "/auth/refresh", {
      method: "POST",
      body: { refreshToken: login.body.refreshToken, deviceId: `staging-refresh-${suffix}` }
    });
    assert.equal(refreshed.response.status, 200);
    accessToken = refreshed.body.accessToken;

    const replayedRefresh = await requestJSON(baseURL, "/auth/refresh", {
      method: "POST",
      body: { refreshToken: login.body.refreshToken }
    });
    assert.equal(replayedRefresh.response.status, 401);

    const logout = await fetch(`${baseURL}/auth/logout`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: refreshed.body.refreshToken })
    });
    assert.equal(logout.status, 204);

    const loggedOutRefresh = await requestJSON(baseURL, "/auth/refresh", {
      method: "POST",
      body: { refreshToken: refreshed.body.refreshToken }
    });
    assert.equal(loggedOutRefresh.response.status, 401);

    const initialProfile = await requestJSON(baseURL, "/profile", {
      headers: authHeaders(accessToken)
    });
    assert.equal(initialProfile.response.status, 200);
    assert.equal(initialProfile.body.profile, null);

    const profile = await requestJSON(baseURL, "/profile", {
      method: "PUT",
      headers: authHeaders(accessToken),
      body: {
        displayName: "Staging E2E",
        birthYear: 1992,
        sex: "prefer_not_to_say",
        heightCm: 170,
        weightKg: 65,
        todaySteps: 4321,
        exerciseMinutes: 20,
        restingHeartRate: 64,
        sleepHours: 7.1,
        healthDataSource: "manual",
        healthDataSyncedAt: "2026-07-21T08:00:00.000Z"
      }
    });
    assert.equal(profile.response.status, 200);
    assert.equal(profile.body.profile.displayName, "Staging E2E");

    const firstClientId = randomUUID();
    const reading = await requestJSON(baseURL, "/readings", {
      method: "POST",
      headers: authHeaders(accessToken),
      body: {
        clientId: firstClientId,
        systolic: 128,
        diastolic: 82,
        pulse: 71,
        measuredAt: "2026-07-21T07:45:00.000Z",
        source: "manual",
        note: "staging e2e"
      }
    });
    assert.equal(reading.response.status, 201);
    const readingId = reading.body.reading.id;

    const invalidPartialReadingUpdate = await requestJSON(baseURL, `/readings/${readingId}`, {
      method: "PUT",
      headers: authHeaders(accessToken),
      body: { diastolic: 140 }
    });
    if (
      invalidPartialReadingUpdate.response.status !== 400
      || invalidPartialReadingUpdate.body.code !== "INVALID_READING_VALUES"
    ) {
      featureFailures.push(
        `partial reading invariant expected 400 INVALID_READING_VALUES, got ${invalidPartialReadingUpdate.response.status} ${invalidPartialReadingUpdate.body.code ?? "no-code"}`
      );
    }

    const updatedReading = await requestJSON(baseURL, `/readings/${readingId}`, {
      method: "PUT",
      headers: authHeaders(accessToken),
      body: { systolic: 130, diastolic: 84 }
    });
    assert.equal(updatedReading.response.status, 200);

    const secondClientId = randomUUID();
    const sync = await requestJSON(baseURL, "/sync/readings", {
      method: "POST",
      headers: authHeaders(accessToken),
      body: {
        readings: [{
          clientId: secondClientId,
          systolic: 124,
          diastolic: 79,
          pulse: 68,
          measuredAt: "2026-07-21T20:30:00.000Z",
          source: "health_import",
          note: null
        }]
      }
    });
    assert.equal(sync.response.status, 200);
    assert.equal(sync.body.readings.length, 1);

    const readings = await requestJSON(baseURL, "/readings?limit=10", {
      headers: authHeaders(accessToken)
    });
    assert.equal(readings.response.status, 200);
    assert.equal(readings.body.readings.length, 2);

    const interpretation = await requestJSON(baseURL, "/readings/interpretation", {
      method: "POST",
      headers: authHeaders(accessToken),
      body: {
        systolicBp: 130,
        diastolicBp: 84,
        bpMonitorPulse: 71,
        measurementTime: "2026-07-21T07:45:00.000Z",
        recentBpReadings: []
      }
    });
    assert.equal(interpretation.response.status, 200);
    assert.equal(typeof interpretation.body.interpretation.summary, "string");

    const deleteReading = await fetch(`${baseURL}/readings/${readingId}`, {
      method: "DELETE",
      headers: authHeaders(accessToken)
    });
    assert.equal(deleteReading.status, 204);

    const unauthenticatedRecognition = await requestJSON(baseURL, "/recognize-bp", {
      method: "POST",
      body: {}
    });
    if (unauthenticatedRecognition.response.status !== 401) {
      featureFailures.push(
        `recognize-bp auth expected 401, got ${unauthenticatedRecognition.response.status}`
      );
    }

    const unauthenticatedMeals = await requestJSON(baseURL, "/meal-records?date=2026-07-21");
    if (unauthenticatedMeals.response.status !== 401) {
      featureFailures.push(`meal-records auth expected 401, got ${unauthenticatedMeals.response.status}`);
    }

    const mealList = await requestJSON(baseURL, "/meal-records?date=2026-07-21", {
      headers: authHeaders(accessToken)
    });
    if (mealList.response.status !== 200) {
      featureFailures.push(`meal-records list expected 200, got ${mealList.response.status}`);
    }

    if (mealList.response.status === 200) {
      const image = readFileSync(new URL("../../../hypertension/Assets.xcassets/TodayCardLunch.imageset/today-card-lunch.png", import.meta.url));
      const mealAnalysis = await requestJSON(baseURL, "/meal-records/analyze", {
        method: "POST",
        headers: authHeaders(accessToken),
        body: {
          mealType: "lunch",
          mealDate: "2026-07-21",
          recordedAt: "2026-07-21T12:30:00.000Z",
          timeZone: "Europe/London",
          imageBase64: `data:image/png;base64,${image.toString("base64")}`
        }
      });
      if (![200, 422].includes(mealAnalysis.response.status)) {
        featureFailures.push(`meal analysis expected 200 or 422, got ${mealAnalysis.response.status}`);
      }
      if (mealAnalysis.response.status === 200) {
        const mealsAfterAnalysis = await requestJSON(baseURL, "/meal-records?date=2026-07-21", {
          headers: authHeaders(accessToken)
        });
        if (!mealsAfterAnalysis.body.records?.some((record: { mealType: string }) => record.mealType === "lunch")) {
          featureFailures.push("meal analysis succeeded but persisted lunch record was not listed");
        }
      }
    }

    const unauthenticatedActions = await requestJSON(baseURL, "/action-adjustments/trend-suggestions", {
      method: "POST",
      body: actionPayload()
    });
    if (unauthenticatedActions.response.status !== 401) {
      featureFailures.push(`action-adjustments auth expected 401, got ${unauthenticatedActions.response.status}`);
    }

    const actions = await requestJSON(baseURL, "/action-adjustments/trend-suggestions", {
      method: "POST",
      headers: authHeaders(accessToken),
      body: actionPayload()
    });
    if (actions.response.status !== 200) {
      featureFailures.push(`action-adjustments expected 200, got ${actions.response.status}`);
    }

    assert.deepEqual(featureFailures, []);
  } finally {
    if (accessToken) {
      const cleanup = await fetch(`${baseURL}/auth/account`, {
        method: "DELETE",
        headers: authHeaders(accessToken),
        body: JSON.stringify({ password })
      });
      assert.equal(cleanup.status, 204, "staging E2E account cleanup failed");
    }
  }
});

function actionPayload() {
  return {
    now: "2026-07-21T18:00:00.000Z",
    timeZone: "Europe/London",
    todayActions: [{
      id: "66666666-6666-4666-8666-666666666666",
      type: "exercise",
      title: "原地踏步",
      scheduledStartAt: "2026-07-21T15:00:00.000Z",
      durationMinutes: 20,
      status: "missed",
      completedAt: null
    }],
    recentActions: []
  };
}

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
  let body: any = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = { raw: text };
  }
  return { response, body };
}

function assertSafeStagingURL(value: string): void {
  const url = new URL(value);
  assert.equal(url.protocol, "https:");
  assert.equal(url.hostname, "bphealth-api-staging.onrender.com");
}
