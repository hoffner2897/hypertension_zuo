import Foundation

struct BloodPressureReadingAPIService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func sync(readings: [LocalQueuedReading]) async throws -> SyncReadingsResponse {
        try await apiClient.post(
            "/sync/readings",
            body: SyncReadingsRequest(readings: readings.map(SyncReadingInput.init)),
            requiresAuth: true
        )
    }

    func list(
        limit: Int = 100,
        cursor: String? = nil,
        includeDeleted: Bool = false
    ) async throws -> ListReadingsResponse {
        var path = "/readings?limit=\(limit)"
        if includeDeleted {
            path += "&includeDeleted=true"
        }
        if let cursor,
           let encodedCursor = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&cursor=\(encodedCursor)"
        }

        return try await apiClient.get(
            path,
            requiresAuth: true
        )
    }

    func find(clientId: UUID) async throws -> RemoteBloodPressureReading? {
        var cursor: String?
        var visitedCursors = Set<String>()

        repeat {
            let response = try await list(limit: 100, cursor: cursor)
            if let match = response.readings.first(where: { $0.clientId == clientId }) {
                return match
            }

            cursor = response.nextCursor
            if let cursor, !visitedCursors.insert(cursor).inserted {
                break
            }
        } while cursor != nil

        return nil
    }

    func update(id: String, draft: BPReadingDraft) async throws -> UpdateReadingResponse {
        try await apiClient.put(
            "/readings/\(id)",
            body: UpdateReadingRequest(draft: draft),
            requiresAuth: true
        )
    }

    func delete(id: String) async throws {
        try await apiClient.delete(
            "/readings/\(id)",
            body: DeleteReadingRequest(),
            requiresAuth: true
        )
    }

    func interpret(reading: BPInterpretationReadingSnapshot, recentReadings: [BPInterpretationReadingSnapshot]) async throws -> BPInterpretationResponse {
        try await apiClient.post(
            "/readings/interpretation",
            body: BPInterpretationRequest(reading: reading, recentReadings: recentReadings),
            requiresAuth: true
        )
    }
}

struct SyncReadingsResponse: Decodable {
    let readings: [RemoteBloodPressureReading]
}

struct RemoteBloodPressureReading: Decodable {
    let id: String
    let clientId: UUID
    let systolic: Int?
    let diastolic: Int?
    let pulse: Int?
    let measuredAt: String?
    let source: String?
    let deletedAt: String?
}

struct ListReadingsResponse: Decodable {
    let readings: [RemoteBloodPressureReading]
    let nextCursor: String?
}

struct UpdateReadingResponse: Decodable {
    let reading: RemoteBloodPressureReading
}

struct BPInterpretationResponse: Decodable {
    let interpretation: BPInterpretation
}

struct BPInterpretation: Decodable, Equatable {
    let category: BPInterpretationCategory
    let severity: BPInterpretationSeverity
    let bloodPressureSituation: [String]
    let reasons: [String]
    let nextSteps: [String]
    let safetyNote: String
    let disclaimer: String
}

enum BPInterpretationCategory: String, Decodable {
    case normal
    case borderline
    case highHome = "high_home"
    case low
    case urgent
    case insufficientData = "insufficient_data"
}

enum BPInterpretationSeverity: String, Decodable {
    case reassuring
    case watch
    case `repeat`
    case followUp = "follow_up"
    case urgent
}

struct BPInterpretationReadingSnapshot {
    let id: UUID
    let systolic: Int
    let diastolic: Int
    let pulse: Int?
    let measuredAt: Date

    @MainActor
    init(_ reading: BloodPressureReading) {
        id = reading.id
        systolic = reading.systolic
        diastolic = reading.diastolic
        pulse = reading.pulse
        measuredAt = reading.measuredAt
    }
}

private struct BPInterpretationRequest: Encodable {
    let systolicBp: Int
    let diastolicBp: Int
    let bpMonitorPulse: Int?
    let measurementTime: String
    let timeZone: String
    let recentBpReadings: [BPRecentInterpretationReading]

    nonisolated init(reading: BPInterpretationReadingSnapshot, recentReadings: [BPInterpretationReadingSnapshot]) {
        systolicBp = reading.systolic
        diastolicBp = reading.diastolic
        bpMonitorPulse = reading.pulse
        measurementTime = Self.formatDate(reading.measuredAt)
        timeZone = TimeZone.current.identifier
        recentBpReadings = recentReadings
            .filter { $0.id != reading.id }
            .prefix(20)
            .map(BPRecentInterpretationReading.init)
    }

    nonisolated fileprivate static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

private struct BPRecentInterpretationReading: Encodable {
    let systolicBp: Int
    let diastolicBp: Int
    let measurementTime: String

    nonisolated init(_ reading: BPInterpretationReadingSnapshot) {
        systolicBp = reading.systolic
        diastolicBp = reading.diastolic
        measurementTime = BPInterpretationRequest.formatDate(reading.measuredAt)
    }
}

private struct SyncReadingsRequest: Encodable {
    let readings: [SyncReadingInput]
}

private struct UpdateReadingRequest: Encodable {
    let systolic: Int
    let diastolic: Int
    let pulse: Int?
    let measuredAt: String

    init(draft: BPReadingDraft) {
        systolic = Int(draft.systolic.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        diastolic = Int(draft.diastolic.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let pulseText = draft.pulse.trimmingCharacters(in: .whitespacesAndNewlines)
        pulse = pulseText.isEmpty ? nil : Int(pulseText)
        measuredAt = BPInterpretationRequest.formatDate(draft.measuredAt)
    }
}

private struct DeleteReadingRequest: Encodable {}

private struct SyncReadingInput: Encodable {
    let clientId: UUID
    let systolic: Int
    let diastolic: Int
    let pulse: Int?
    let measuredAt: String
    let source: String
    let note: String?

    init(_ reading: LocalQueuedReading) {
        let formatter = ISO8601DateFormatter()
        clientId = reading.clientId
        systolic = reading.systolic
        diastolic = reading.diastolic
        pulse = reading.pulse
        measuredAt = formatter.string(from: reading.measuredAt)
        source = reading.source
        note = reading.note
    }
}
