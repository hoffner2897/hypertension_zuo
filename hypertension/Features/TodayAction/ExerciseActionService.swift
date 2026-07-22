import Foundation

struct RemoteExerciseAction: Decodable, Equatable, Identifiable {
    let id: String
    let exerciseId: String
    let title: String
    let scene: String
    let energy: String
    let contexts: [String]
    let scheduledStartAt: String
    let durationMinutes: Int
    let status: String
    let completedAt: String?
    let movementAdvice: String
    let intensityAdvice: String
    let localDay: String
    let clientUpdatedAt: String
    let createdAt: String
    let updatedAt: String
}

struct ExerciseActionSyncInput: Encodable, Equatable {
    let exerciseId: String
    let title: String
    let scene: String
    let energy: String
    let contexts: [String]
    let scheduledStartAt: String
    let durationMinutes: Int
    let status: String
    let completedAt: String?
    let movementAdvice: String
    let intensityAdvice: String
    let localDay: String
    let clientUpdatedAt: String
}

struct ExerciseActionUpsertResult: Decodable, Equatable {
    let action: RemoteExerciseAction
    let applied: Bool
}

struct ExerciseActionService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func actions(for date: Date = Date()) async throws -> [RemoteExerciseAction] {
        let response: ExerciseActionListResponse = try await apiClient.get(
            "/exercise-actions?localDay=\(Self.dayFormatter.string(from: date))",
            requiresAuth: true
        )
        return response.actions
    }

    func upsert(id: UUID, input: ExerciseActionSyncInput) async throws -> ExerciseActionUpsertResult {
        try await apiClient.put(
            "/exercise-actions/\(id.uuidString.lowercased())",
            body: input,
            requiresAuth: true
        )
    }

    static func dayString(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func isoString(for date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func date(fromISO8601 value: String) -> Date? {
        isoFormatter.date(from: value) ?? fallbackISOFormatter.date(from: value)
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

    private static let fallbackISOFormatter = ISO8601DateFormatter()
}

private struct ExerciseActionListResponse: Decodable {
    let actions: [RemoteExerciseAction]
}

extension ExerciseActionSyncInput {
    init?(item: TodayActionItem) {
        guard let exerciseId = item.exerciseId,
              let scene = item.exerciseScene,
              let energy = item.exerciseEnergy,
              let movementAdvice = item.exerciseMovementAdvice,
              let intensityAdvice = item.exerciseIntensityAdvice else {
            return nil
        }

        self.init(
            exerciseId: exerciseId,
            title: item.title,
            scene: scene,
            energy: energy,
            contexts: item.exerciseContexts,
            scheduledStartAt: ExerciseActionService.isoString(for: item.scheduledStartAt),
            durationMinutes: item.durationMinutes,
            status: item.status.actionHistoryAPIValue,
            completedAt: item.completedAt.map { ExerciseActionService.isoString(for: $0) },
            movementAdvice: movementAdvice,
            intensityAdvice: intensityAdvice,
            localDay: ExerciseActionService.dayString(for: item.scheduledStartAt),
            clientUpdatedAt: ExerciseActionService.isoString(for: item.clientUpdatedAt)
        )
    }
}

extension TodayActionItem {
    init?(remoteExerciseAction action: RemoteExerciseAction, sortOrder: Int = 0) {
        guard let id = UUID(uuidString: action.id),
              let scheduledStartAt = ExerciseActionService.date(fromISO8601: action.scheduledStartAt),
              let clientUpdatedAt = ExerciseActionService.date(fromISO8601: action.clientUpdatedAt),
              let status = TodayActionStatus(actionHistoryAPIValue: action.status) else {
            return nil
        }

        self.init(
            id: id,
            type: .walk,
            title: action.title,
            description: action.movementAdvice,
            reason: "根据当前场景、精力和情景状态推荐的低门槛运动。",
            scheduledStartAt: scheduledStartAt,
            durationMinutes: action.durationMinutes,
            status: status,
            completedAt: action.completedAt.flatMap { ExerciseActionService.date(fromISO8601: $0) },
            sortOrder: sortOrder,
            exerciseId: action.exerciseId,
            exerciseScene: action.scene,
            exerciseEnergy: action.energy,
            exerciseContexts: action.contexts,
            exerciseMovementAdvice: action.movementAdvice,
            exerciseIntensityAdvice: action.intensityAdvice,
            clientUpdatedAt: clientUpdatedAt
        )
    }
}
