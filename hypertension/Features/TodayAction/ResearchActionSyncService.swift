import Foundation

struct ResearchActionSyncService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func sync(items: [TodayActionItem], now: Date = Date()) async throws {
        let body = ResearchActionSnapshotInput(
            localDay: Self.dayFormatter.string(from: now),
            timeZone: TimeZone.current.identifier,
            capturedAt: Self.isoFormatter.string(from: now),
            items: items.sorted(by: Self.researchSort).map(ResearchActionSnapshotItem.init)
        )
        let _: ResearchActionSyncResponse = try await apiClient.post(
            "/research-actions/sync",
            body: body,
            requiresAuth: true
        )
    }

    private static func researchSort(_ left: TodayActionItem, _ right: TodayActionItem) -> Bool {
        if left.sortOrder != right.sortOrder {
            return left.sortOrder < right.sortOrder
        }
        if left.scheduledStartAt != right.scheduledStartAt {
            return left.scheduledStartAt < right.scheduledStartAt
        }
        return left.id.uuidString < right.id.uuidString
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct ResearchActionSnapshotInput: Encodable {
    let localDay: String
    let timeZone: String
    let capturedAt: String
    let items: [ResearchActionSnapshotItem]
}

private struct ResearchActionSnapshotItem: Encodable {
    let id: String
    let type: String
    let title: String
    let description: String
    let reason: String
    let scheduledStartAt: String
    let scheduledEndAt: String
    let durationMinutes: Int
    let status: String
    let effectiveStatus: String
    let completedAt: String?
    let sortOrder: Int
    let bloodPressureText: String?
    let adviceText: String?
    let exerciseId: String?
    let exerciseScene: String?
    let exerciseEnergy: String?
    let exerciseContexts: [String]
    let exerciseMovementAdvice: String?
    let exerciseIntensityAdvice: String?
    let actualStartedAt: String?
    let actualEndedAt: String?
    let actualDurationSeconds: Int?
    let completionMode: String?
    let clientUpdatedAt: String

    init(item: TodayActionItem) {
        let now = Date()
        id = item.id.uuidString.lowercased()
        type = item.type.rawValue
        title = item.title
        description = item.description
        reason = item.reason
        scheduledStartAt = ResearchActionSyncService.isoString(item.scheduledStartAt)
        scheduledEndAt = ResearchActionSyncService.isoString(item.scheduledEndAt)
        durationMinutes = item.durationMinutes
        status = item.status.researchAPIValue
        effectiveStatus = item.effectiveStatus(now: now).researchAPIValue
        completedAt = item.completedAt.map { ResearchActionSyncService.isoString($0) }
        sortOrder = item.sortOrder
        bloodPressureText = item.bloodPressureText
        adviceText = item.adviceText
        exerciseId = item.exerciseId
        exerciseScene = item.exerciseScene
        exerciseEnergy = item.exerciseEnergy
        exerciseContexts = item.exerciseContexts
        exerciseMovementAdvice = item.exerciseMovementAdvice
        exerciseIntensityAdvice = item.exerciseIntensityAdvice
        actualStartedAt = item.actualStartedAt.map { ResearchActionSyncService.isoString($0) }
        actualEndedAt = item.actualEndedAt.map { ResearchActionSyncService.isoString($0) }
        actualDurationSeconds = item.actualDurationSeconds
        completionMode = item.completionMode?.rawValue
        clientUpdatedAt = ResearchActionSyncService.isoString(item.clientUpdatedAt)
    }
}

private struct ResearchActionSyncResponse: Decodable {
    let applied: Bool
    let version: Int
    let eventCount: Int
    let capturedAt: String
}

private extension ResearchActionSyncService {
    static func isoString(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }
}

private extension TodayActionStatus {
    var researchAPIValue: String {
        switch self {
        case .inProgress:
            return "in_progress"
        default:
            return rawValue
        }
    }
}
