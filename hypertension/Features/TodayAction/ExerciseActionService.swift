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
    let actualStartedAt: String?
    let timerLastResumedAt: String?
    let timerAccumulatedSeconds: Int
    let actualEndedAt: String?
    let actualDurationSeconds: Int?
    let completionMode: String?
    let movementAdvice: String
    let intensityAdvice: String
    let localDay: String
    let clientUpdatedAt: String
    let createdAt: String
    let updatedAt: String

    init(
        id: String, exerciseId: String, title: String, scene: String, energy: String,
        contexts: [String], scheduledStartAt: String, durationMinutes: Int, status: String,
        completedAt: String?, actualStartedAt: String? = nil, timerLastResumedAt: String? = nil,
        timerAccumulatedSeconds: Int = 0, actualEndedAt: String? = nil,
        actualDurationSeconds: Int? = nil, completionMode: String? = nil,
        movementAdvice: String, intensityAdvice: String, localDay: String,
        clientUpdatedAt: String, createdAt: String, updatedAt: String
    ) {
        self.id = id; self.exerciseId = exerciseId; self.title = title; self.scene = scene
        self.energy = energy; self.contexts = contexts; self.scheduledStartAt = scheduledStartAt
        self.durationMinutes = durationMinutes; self.status = status; self.completedAt = completedAt
        self.actualStartedAt = actualStartedAt; self.timerLastResumedAt = timerLastResumedAt
        self.timerAccumulatedSeconds = timerAccumulatedSeconds; self.actualEndedAt = actualEndedAt
        self.actualDurationSeconds = actualDurationSeconds; self.completionMode = completionMode
        self.movementAdvice = movementAdvice; self.intensityAdvice = intensityAdvice; self.localDay = localDay
        self.clientUpdatedAt = clientUpdatedAt; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
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
    let actualStartedAt: String?
    let timerLastResumedAt: String?
    let timerAccumulatedSeconds: Int
    let actualEndedAt: String?
    let actualDurationSeconds: Int?
    let completionMode: String?
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

    func delete(id: UUID) async throws {
        try await apiClient.delete(
            "/exercise-actions/\(id.uuidString.lowercased())",
            body: EmptyExerciseActionDeleteRequest(),
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
            actualStartedAt: item.actualStartedAt.map { ExerciseActionService.isoString(for: $0) },
            timerLastResumedAt: item.timerLastResumedAt.map { ExerciseActionService.isoString(for: $0) },
            timerAccumulatedSeconds: item.timerAccumulatedSeconds,
            actualEndedAt: item.actualEndedAt.map { ExerciseActionService.isoString(for: $0) },
            actualDurationSeconds: item.actualDurationSeconds,
            completionMode: item.completionMode?.rawValue,
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
              let decodedStatus = TodayActionStatus(actionHistoryAPIValue: action.status) else {
            return nil
        }

        let completedAt = action.completedAt.flatMap { ExerciseActionService.date(fromISO8601: $0) }
        let actualStartedAt = action.actualStartedAt.flatMap { ExerciseActionService.date(fromISO8601: $0) }
        let actualEndedAt = action.actualEndedAt.flatMap { ExerciseActionService.date(fromISO8601: $0) }
        let status: TodayActionStatus
        if decodedStatus == .missed,
           actualStartedAt != nil,
           actualEndedAt == nil,
           completedAt == nil {
            // Older clients could upload a regressed `missed` state after a
            // running timer crossed its planned end. Recover it on download.
            status = .inProgress
        } else {
            status = decodedStatus
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
            completedAt: completedAt,
            sortOrder: sortOrder,
            exerciseId: action.exerciseId,
            exerciseScene: action.scene,
            exerciseEnergy: action.energy,
            exerciseContexts: action.contexts,
            exerciseMovementAdvice: action.movementAdvice,
            exerciseIntensityAdvice: action.intensityAdvice,
            actualStartedAt: actualStartedAt,
            timerLastResumedAt: action.timerLastResumedAt.flatMap { ExerciseActionService.date(fromISO8601: $0) },
            timerAccumulatedSeconds: action.timerAccumulatedSeconds,
            actualEndedAt: actualEndedAt,
            actualDurationSeconds: action.actualDurationSeconds,
            completionMode: action.completionMode.flatMap(ExerciseCompletionMode.init(rawValue:)),
            clientUpdatedAt: clientUpdatedAt
        )
    }

    func shouldAcceptRemoteExerciseSync(_ remote: TodayActionItem) -> Bool {
        let timestampDelta = remote.clientUpdatedAt.timeIntervalSince(clientUpdatedAt)
        if timestampDelta > 0.01 {
            return true
        }
        if timestampDelta < -0.01 {
            return false
        }

        // For the same logical write, keep the state that contains more user
        // progress. This prevents a stale pending/missed snapshot from
        // replacing an active or completed timer.
        return remote.status.exerciseSyncProgressRank > status.exerciseSyncProgressRank
    }
}

private extension TodayActionStatus {
    var exerciseSyncProgressRank: Int {
        switch self {
        case .pending: 0
        case .missed: 1
        case .skipped: 2
        case .inProgress: 3
        case .completed: 4
        }
    }
}

private struct EmptyExerciseActionDeleteRequest: Encodable {}
