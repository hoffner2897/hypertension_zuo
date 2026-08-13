import XCTest
@testable import hypertension

final class ResearchActionSyncTests: XCTestCase {
    func testSyncSendsCompleteTreeWithoutImageData() async throws {
        let requestBox = RequestBox()
        let apiClient = APIClient { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                Data(#"{"applied":true,"version":1,"eventCount":2,"capturedAt":"2026-08-13T10:00:00.000Z"}"#.utf8),
                response
            )
        }
        apiClient.baseURL = URL(string: "https://example.test")!
        apiClient.accessToken = "test-token"
        let service = ResearchActionSyncService(apiClient: apiClient)
        let now = Date(timeIntervalSince1970: 1_786_614_400)
        let item = TodayActionItem(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            type: .diet,
            title: "早餐建议",
            description: "选择低盐早餐。",
            reason: "记录饮食选择。",
            scheduledStartAt: now,
            durationMinutes: 20,
            status: .completed,
            completedAt: now,
            sortOrder: 0,
            adviceText: "饮食结构：增加蔬菜。"
        )

        try await service.sync(items: [item], now: now)

        let request = try XCTUnwrap(requestBox.request)
        XCTAssertEqual(request.url?.path, "/research-actions/sync")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let items = try XCTUnwrap(json["items"] as? [[String: Any]])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0]["title"] as? String, "早餐建议")
        XCTAssertEqual(items[0]["status"] as? String, "completed")
        XCTAssertNil(items[0]["image"])
        XCTAssertNil(items[0]["imageData"])
    }
}

private final class RequestBox: @unchecked Sendable {
    var request: URLRequest?
}
