import Foundation

struct StoredActionObservation: Codable, Hashable {
    let id: UUID
    let type: String
    let title: String
    let scheduledStartAt: Date
    let durationMinutes: Int
    let status: String
    let completedAt: Date?
    let localDay: String
    let exerciseId: String?
    let exerciseScene: String?
    let exerciseEnergy: String?
    let exerciseContexts: [String]?
    let exerciseMovementAdvice: String?
    let exerciseIntensityAdvice: String?
    let actualStartedAt: Date?
    let timerLastResumedAt: Date?
    let timerAccumulatedSeconds: Int?
    let actualEndedAt: Date?
    let actualDurationSeconds: Int?
    let completionMode: String?
    let clientUpdatedAt: Date?

    init(item: TodayActionItem, now: Date = Date()) {
        id = item.id
        type = item.type.actionHistoryAPIType
        title = item.title
        scheduledStartAt = item.scheduledStartAt
        durationMinutes = item.durationMinutes
        status = item.effectiveStatus(now: now).actionHistoryAPIValue
        completedAt = item.completedAt
        localDay = Self.dayFormatter.string(from: item.scheduledStartAt)
        exerciseId = item.exerciseId
        exerciseScene = item.exerciseScene
        exerciseEnergy = item.exerciseEnergy
        exerciseContexts = item.exerciseContexts
        exerciseMovementAdvice = item.exerciseMovementAdvice
        exerciseIntensityAdvice = item.exerciseIntensityAdvice
        actualStartedAt = item.actualStartedAt
        timerLastResumedAt = item.timerLastResumedAt
        timerAccumulatedSeconds = item.timerAccumulatedSeconds
        actualEndedAt = item.actualEndedAt
        actualDurationSeconds = item.actualDurationSeconds
        completionMode = item.completionMode?.rawValue
        clientUpdatedAt = item.clientUpdatedAt
    }

    var normalizedStatus: String {
        normalizedStatus(at: Date())
    }

    func normalizedStatus(at now: Date) -> String {
        // A running timer remains an active observation after its planned end.
        // The user must explicitly confirm completion or continue exercising.
        if status == "in_progress" {
            return status
        }

        // Repair observations written by older builds that converted a started
        // timer to `missed` when the app was restored after the planned end.
        if status == "missed",
           actualStartedAt != nil,
           actualEndedAt == nil,
           completedAt == nil {
            return "in_progress"
        }

        guard status == "pending" else {
            return status
        }

        let end = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: scheduledStartAt) ?? scheduledStartAt
        return end < now ? "missed" : status
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum ActionHistoryStore {
    static func restoreToday(_ items: [TodayActionItem], userId: String, now: Date = Date()) -> [TodayActionItem] {
        guard !userId.isEmpty else { return items }
        let day = dayFormatter.string(from: now)
        var saved = load(userId: userId).filter { $0.localDay == day }
        guard !saved.isEmpty else { return items }

        var restoredItems = items.map { item in
            guard let observationIndex = saved.indices
                .filter({
                    saved[$0].type == item.type.actionHistoryAPIType &&
                    saved[$0].title == item.title
                })
                .min(by: {
                    abs(saved[$0].scheduledStartAt.timeIntervalSince(item.scheduledStartAt)) <
                    abs(saved[$1].scheduledStartAt.timeIntervalSince(item.scheduledStartAt))
                }) else {
                return item
            }

            let observation = saved.remove(at: observationIndex)
            var restored = item
            restored.scheduledStartAt = observation.scheduledStartAt
            restored.durationMinutes = observation.durationMinutes
            restored.scheduledEndAt = Calendar.current.date(
                byAdding: .minute,
                value: observation.durationMinutes,
                to: observation.scheduledStartAt
            ) ?? observation.scheduledStartAt
            restored.status = TodayActionStatus(actionHistoryAPIValue: observation.normalizedStatus(at: now)) ?? item.status
            restored.displayStatus = restored.status
            restored.completedAt = observation.completedAt
            restored.exerciseId = observation.exerciseId
            restored.exerciseScene = observation.exerciseScene
            restored.exerciseEnergy = observation.exerciseEnergy
            restored.exerciseContexts = observation.exerciseContexts ?? []
            restored.exerciseMovementAdvice = observation.exerciseMovementAdvice
            restored.exerciseIntensityAdvice = observation.exerciseIntensityAdvice
            restored.actualStartedAt = observation.actualStartedAt
            restored.timerLastResumedAt = observation.timerLastResumedAt
            restored.timerAccumulatedSeconds = observation.timerAccumulatedSeconds ?? 0
            restored.actualEndedAt = observation.actualEndedAt
            restored.actualDurationSeconds = observation.actualDurationSeconds
            restored.completionMode = observation.completionMode.flatMap(ExerciseCompletionMode.init(rawValue:))
            restored.clientUpdatedAt = observation.clientUpdatedAt ?? restored.clientUpdatedAt
            return restored
        }

        // Actions generated by the user are not part of the static daily template.
        // Rebuild any remaining observations so they survive an app relaunch.
        restoredItems.append(contentsOf: saved.compactMap { observation in
            TodayActionItem(actionHistoryObservation: observation, now: now)
        })
        restoredItems.sort { $0.scheduledStartAt < $1.scheduledStartAt }
        for index in restoredItems.indices {
            restoredItems[index].sortOrder = index
        }
        return restoredItems
    }

    static func saveToday(_ items: [TodayActionItem], userId: String, now: Date = Date()) {
        guard !userId.isEmpty else { return }
        let today = dayFormatter.string(from: now)
        var observations = load(userId: userId).filter { $0.localDay != today }
        observations.append(contentsOf: items.map { StoredActionObservation(item: $0, now: now) })

        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Calendar.current.startOfDay(for: now)) ?? now
        observations = observations
            .filter { $0.scheduledStartAt >= cutoff }
            .sorted { $0.scheduledStartAt < $1.scheduledStartAt }
            .suffix(100)
            .map { $0 }
        persist(observations, userId: userId)
    }

    static func recent(userId: String, excluding date: Date = Date()) -> [StoredActionObservation] {
        guard !userId.isEmpty else { return [] }
        let today = dayFormatter.string(from: date)
        return load(userId: userId)
            .filter { $0.localDay != today }
            .sorted { $0.scheduledStartAt > $1.scheduledStartAt }
    }

    static func removeAll(userId: String) {
        guard !userId.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: storageKey(userId: userId))
    }

    private static func load(userId: String) -> [StoredActionObservation] {
        guard let data = UserDefaults.standard.data(forKey: storageKey(userId: userId)) else {
            return []
        }
        return (try? decoder.decode([StoredActionObservation].self, from: data)) ?? []
    }

    private static func persist(_ observations: [StoredActionObservation], userId: String) {
        guard let data = try? encoder.encode(observations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey(userId: userId))
    }

    private static func storageKey(userId: String) -> String {
        "bphealth.action-history.\(userId)"
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension TodayActionItem {
    init?(actionHistoryObservation observation: StoredActionObservation, now: Date = Date()) {
        guard let type = TodayActionType(actionHistoryAPIType: observation.type) else {
            return nil
        }

        self.init(
            id: observation.id,
            type: type,
            title: observation.title,
            description: type.description(durationMinutes: observation.durationMinutes),
            reason: type.reason,
            scheduledStartAt: observation.scheduledStartAt,
            durationMinutes: observation.durationMinutes,
            status: TodayActionStatus(actionHistoryAPIValue: observation.normalizedStatus(at: now)) ?? .pending,
            completedAt: observation.completedAt,
            sortOrder: 0,
            exerciseId: observation.exerciseId,
            exerciseScene: observation.exerciseScene,
            exerciseEnergy: observation.exerciseEnergy,
            exerciseContexts: observation.exerciseContexts ?? [],
            exerciseMovementAdvice: observation.exerciseMovementAdvice,
            exerciseIntensityAdvice: observation.exerciseIntensityAdvice,
            actualStartedAt: observation.actualStartedAt,
            timerLastResumedAt: observation.timerLastResumedAt,
            timerAccumulatedSeconds: observation.timerAccumulatedSeconds ?? 0,
            actualEndedAt: observation.actualEndedAt,
            actualDurationSeconds: observation.actualDurationSeconds,
            completionMode: observation.completionMode.flatMap(ExerciseCompletionMode.init(rawValue:)),
            clientUpdatedAt: observation.clientUpdatedAt ?? observation.scheduledStartAt
        )
    }
}

extension TodayActionType {
    var actionHistoryAPIType: String {
        switch self {
        case .bpRecheck:
            "blood_pressure"
        case .diet:
            "diet"
        case .walk:
            "exercise"
        case .rest, .hydration, .sleep, .custom:
            "other"
        }
    }

    init?(actionHistoryAPIType: String) {
        switch actionHistoryAPIType {
        case "blood_pressure": self = .bpRecheck
        case "diet": self = .diet
        case "exercise": self = .walk
        case "other": self = .custom
        default: return nil
        }
    }
}

extension TodayActionStatus {
    var actionHistoryAPIValue: String {
        switch self {
        case .pending:
            "pending"
        case .inProgress:
            "in_progress"
        case .completed:
            "completed"
        case .skipped:
            "skipped"
        case .missed:
            "missed"
        }
    }

    init?(actionHistoryAPIValue: String) {
        switch actionHistoryAPIValue {
        case "pending": self = .pending
        case "in_progress": self = .inProgress
        case "completed": self = .completed
        case "skipped": self = .skipped
        case "missed": self = .missed
        default: return nil
        }
    }
}
