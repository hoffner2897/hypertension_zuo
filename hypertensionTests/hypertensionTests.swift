//
//  hypertensionTests.swift
//  hypertensionTests
//
//  Created by Haoyu Zuo on 2026/6/27.
//

import Testing
import Foundation
@testable import hypertension

struct hypertensionTests {

    private struct NetworkTestPayload: Decodable {
        let value: String
    }

    @Test @MainActor func rootRouteRequiresEmailVerificationBeforeProfile() {
        let user = AuthUser(
            id: "user-1",
            email: "person@example.com",
            emailVerified: false,
            profileCompleted: false
        )

        #expect(AppState.route(for: user) == .verifyEmail)
    }

    @Test @MainActor func rootRouteRequiresProfileAfterEmailVerification() {
        let user = AuthUser(
            id: "user-1",
            email: "person@example.com",
            emailVerified: true,
            profileCompleted: false
        )

        #expect(AppState.route(for: user) == .profileSetup)
    }

    @Test @MainActor func rootRouteShowsMainAppOnlyForCompletedUser() {
        let user = AuthUser(
            id: "user-1",
            email: "person@example.com",
            emailVerified: true,
            profileCompleted: true
        )

        #expect(AppState.route(for: user) == .mainApp)
    }

    @Test @MainActor func healthAuthorizationResolverDistinguishesRequestedPartialAndCompleteData() {
        #expect(
            HealthKitAuthorizationResolver.resolve(
                isAvailable: true,
                hasRequestedAuthorization: false,
                readableDataKindCount: 0
            ) == .notDetermined
        )
        #expect(
            HealthKitAuthorizationResolver.resolve(
                isAvailable: true,
                hasRequestedAuthorization: true,
                readableDataKindCount: 0
            ) == .accessRequested
        )
        #expect(
            HealthKitAuthorizationResolver.resolve(
                isAvailable: true,
                hasRequestedAuthorization: true,
                readableDataKindCount: 3
            ) == .partiallyAuthorized
        )
        #expect(
            HealthKitAuthorizationResolver.resolve(
                isAvailable: true,
                hasRequestedAuthorization: true,
                readableDataKindCount: HealthKitDataKind.allCases.count
            ) == .sharingAuthorized
        )
        #expect(
            HealthKitAuthorizationResolver.resolve(
                isAvailable: false,
                hasRequestedAuthorization: true,
                readableDataKindCount: HealthKitDataKind.allCases.count
            ) == .unavailable
        )
    }

    @Test @MainActor func apiClientRefreshesExpiredAccessTokenAndRetriesOnce() async throws {
        var authorizationHeaders: [String?] = []
        var refreshCount = 0
        let client = APIClient { request in
            let authorization = request.value(forHTTPHeaderField: "Authorization")
            authorizationHeaders.append(authorization)

            if authorization == "Bearer expired-token" {
                return self.httpResponse(
                    request: request,
                    statusCode: 401,
                    json: #"{"code":"UNAUTHORIZED"}"#
                )
            }

            return self.httpResponse(
                request: request,
                statusCode: 200,
                json: #"{"value":"ok"}"#
            )
        }
        client.baseURL = URL(string: "https://unit.test")!
        client.accessToken = "expired-token"
        client.setAuthorizationRefreshHandler {
            refreshCount += 1
            return "fresh-token"
        }

        let payload: NetworkTestPayload = try await client.get("/protected", requiresAuth: true)

        #expect(payload.value == "ok")
        #expect(refreshCount == 1)
        #expect(authorizationHeaders == ["Bearer expired-token", "Bearer fresh-token"])
    }

    @Test @MainActor func apiClientDoesNotRetryASecondUnauthorizedResponse() async throws {
        var requestCount = 0
        var refreshCount = 0
        let client = APIClient { request in
            requestCount += 1
            return self.httpResponse(
                request: request,
                statusCode: 401,
                json: #"{"code":"UNAUTHORIZED"}"#
            )
        }
        client.baseURL = URL(string: "https://unit.test")!
        client.accessToken = "expired-token"
        client.setAuthorizationRefreshHandler {
            refreshCount += 1
            return "still-invalid-token"
        }

        do {
            let _: NetworkTestPayload = try await client.get("/protected", requiresAuth: true)
            Issue.record("Expected the retried request to remain unauthorized")
        } catch APIClientError.server(let code, _) {
            #expect(code == "UNAUTHORIZED")
        }

        #expect(refreshCount == 1)
        #expect(requestCount == 2)
    }

    @Test @MainActor func apiClientDeduplicatesConcurrentTokenRefreshes() async throws {
        var expiredRequestCount = 0
        var successfulRequestCount = 0
        var refreshCount = 0
        let client = APIClient { request in
            let authorization = request.value(forHTTPHeaderField: "Authorization")
            if authorization == "Bearer expired-token" {
                expiredRequestCount += 1
                try await Task.sleep(for: .milliseconds(20))
                return self.httpResponse(
                    request: request,
                    statusCode: 401,
                    json: #"{"code":"UNAUTHORIZED"}"#
                )
            }

            successfulRequestCount += 1
            return self.httpResponse(
                request: request,
                statusCode: 200,
                json: #"{"value":"ok"}"#
            )
        }
        client.baseURL = URL(string: "https://unit.test")!
        client.accessToken = "expired-token"
        client.setAuthorizationRefreshHandler {
            refreshCount += 1
            try await Task.sleep(for: .milliseconds(50))
            return "fresh-token"
        }

        async let first: NetworkTestPayload = client.get("/first", requiresAuth: true)
        async let second: NetworkTestPayload = client.get("/second", requiresAuth: true)
        let values = try await [first.value, second.value]

        #expect(values == ["ok", "ok"])
        #expect(refreshCount == 1)
        #expect(expiredRequestCount == 2)
        #expect(successfulRequestCount == 2)
    }

    @Test @MainActor func validationAcceptsValidReading() async throws {
        let viewModel = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "128",
                diastolic: "82",
                pulse: "72",
                measuredAt: Date()
            )
        )

        #expect(viewModel.validate())
        #expect(viewModel.errorMessage == nil)
    }

    @Test @MainActor func validationRequiresSystolic() async throws {
        let viewModel = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "",
                diastolic: "82",
                measuredAt: Date()
            )
        )

        #expect(!viewModel.validate())
        #expect(viewModel.errorMessage == "请输入收缩压。")
    }

    @Test @MainActor func validationRequiresSystolicGreaterThanDiastolic() async throws {
        let viewModel = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "80",
                diastolic: "82",
                measuredAt: Date()
            )
        )

        #expect(!viewModel.validate())
        #expect(viewModel.errorMessage == "收缩压需要大于舒张压。")
    }

    @Test @MainActor func validationRejectsFutureMeasurementTime() async throws {
        let viewModel = BPConfirmReadingViewModel(
            draft: BPReadingDraft(
                systolic: "128",
                diastolic: "82",
                measuredAt: Date().addingTimeInterval(60)
            )
        )

        #expect(!viewModel.validate())
        #expect(viewModel.errorMessage == "测量时间不能晚于当前时间。")
    }

    @Test @MainActor func actionHistoryRestoresTodayAndKeepsOnlyActualRecordedDays() async throws {
        let userId = "action-history-test-\(UUID().uuidString)"
        defer { ActionHistoryStore.removeAll(userId: userId) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayMinusTwo = calendar.date(byAdding: .day, value: -2, to: today)!
        let dayMinusOne = calendar.date(byAdding: .day, value: -1, to: today)!
        let currentStart = calendar.date(byAdding: .hour, value: 23, to: today)!

        ActionHistoryStore.saveToday(
            [makeAction(start: calendar.date(byAdding: .hour, value: 9, to: dayMinusTwo)!, status: .completed)],
            userId: userId,
            now: dayMinusTwo
        )
        ActionHistoryStore.saveToday(
            [makeAction(start: calendar.date(byAdding: .hour, value: 9, to: dayMinusOne)!, status: .skipped)],
            userId: userId,
            now: dayMinusOne
        )

        var current = makeAction(start: currentStart, status: .completed)
        current.completedAt = Date()
        ActionHistoryStore.saveToday([current], userId: userId, now: today)

        let freshCurrent = makeAction(start: currentStart, status: .pending)
        let restored = ActionHistoryStore.restoreToday([freshCurrent], userId: userId, now: today)
        let recent = ActionHistoryStore.recent(userId: userId, excluding: today)

        #expect(restored.first?.status == .completed)
        #expect(recent.count == 2)
        #expect(Set(recent.map(\.localDay)).count == 2)
    }

    @Test @MainActor func pastPendingActionIsNormalizedToMissedForTrendEvidence() async throws {
        let oldStart = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let observation = StoredActionObservation(item: makeAction(start: oldStart, status: .pending), now: oldStart)
        #expect(observation.normalizedStatus == "missed")
    }

    @Test @MainActor func generatedActionSurvivesAppRelaunch() async throws {
        let userId = "generated-action-test-\(UUID().uuidString)"
        defer { ActionHistoryStore.removeAll(userId: userId) }

        let now = Date()
        let generated = TodayActionItem(
            type: .walk,
            title: "骑车",
            description: "轻量骑行",
            reason: "用户偏好",
            scheduledStartAt: now.addingTimeInterval(1_800),
            durationMinutes: 30,
            sortOrder: 99
        )
        ActionHistoryStore.saveToday([generated], userId: userId, now: now)

        let restored = ActionHistoryStore.restoreToday([], userId: userId, now: now)

        #expect(restored.count == 1)
        #expect(restored.first?.id == generated.id)
        #expect(restored.first?.title == "骑车")
        #expect(restored.first?.durationMinutes == 30)
    }

    @MainActor
    private func makeAction(start: Date, status: TodayActionStatus) -> TodayActionItem {
        TodayActionItem(
            type: .walk,
            title: "慢走",
            description: "低门槛运动",
            reason: "测试",
            scheduledStartAt: start,
            durationMinutes: 20,
            status: status,
            completedAt: status == .completed ? start.addingTimeInterval(600) : nil,
            sortOrder: 0
        )
    }

    @MainActor
    private func httpResponse(
        request: URLRequest,
        statusCode: Int,
        json: String
    ) -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(json.utf8), response)
    }

}
