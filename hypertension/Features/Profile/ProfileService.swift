import Foundation

struct ProfileService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchProfile() async throws -> ProfileResponse {
        try await apiClient.get("/profile", requiresAuth: true)
    }

    func saveProfile(
        displayName: String,
        birthYear: Int,
        sex: String,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        todaySteps: Int? = nil,
        exerciseMinutes: Int? = nil,
        restingHeartRate: Int? = nil,
        sleepHours: Double? = nil,
        healthDataSource: String? = nil,
        healthDataSyncedAt: Date? = nil
    ) async throws -> ProfileResponse {
        try await apiClient.put(
            "/profile",
            body: SaveProfileRequest(
                displayName: displayName,
                birthYear: birthYear,
                sex: sex,
                heightCm: heightCm,
                weightKg: weightKg,
                todaySteps: todaySteps,
                exerciseMinutes: exerciseMinutes,
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                healthDataSource: healthDataSource,
                healthDataSyncedAt: healthDataSyncedAt.map(Self.isoFormatter.string(from:))
            ),
            requiresAuth: true
        )
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct SaveProfileRequest: Encodable {
    let displayName: String
    let birthYear: Int
    let sex: String
    let heightCm: Double?
    let weightKg: Double?
    let todaySteps: Int?
    let exerciseMinutes: Int?
    let restingHeartRate: Int?
    let sleepHours: Double?
    let healthDataSource: String?
    let healthDataSyncedAt: String?
}
