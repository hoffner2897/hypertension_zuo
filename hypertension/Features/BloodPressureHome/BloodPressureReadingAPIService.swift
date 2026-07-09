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

    func list(limit: Int = 100) async throws -> ListReadingsResponse {
        try await apiClient.get(
            "/readings?limit=\(limit)",
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

struct BPInterpretationResponse: Decodable {
    let interpretation: BPInterpretation
}

struct BPInterpretation: Decodable, Equatable {
    let category: BPInterpretationCategory
    let severity: BPInterpretationSeverity
    let title: String
    let summary: String
    let reasons: [String]
    let personalContextNotes: [String]
    let measurementQualityNotes: [String]
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
    let recentBpReadings: [BPRecentInterpretationReading]

    nonisolated init(reading: BPInterpretationReadingSnapshot, recentReadings: [BPInterpretationReadingSnapshot]) {
        systolicBp = reading.systolic
        diastolicBp = reading.diastolic
        bpMonitorPulse = reading.pulse
        measurementTime = Self.formatDate(reading.measuredAt)
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
