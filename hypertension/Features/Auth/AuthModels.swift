import Foundation

struct AuthResponse: Decodable {
    let accessToken: String
    let accessTokenExpiresInSeconds: Int
    let refreshToken: String
    let refreshTokenExpiresAt: String
    let deviceId: String
    let user: AuthUser
}

struct AuthUser: Decodable {
    let id: String
    let email: String
    let emailVerified: Bool
    let profileCompleted: Bool
}

struct MeResponse: Decodable {
    let user: AuthUser
}

struct VerifyEmailResponse: Decodable {
    let user: AuthUser
}

struct ProfileResponse: Decodable {
    let profile: UserProfile?
}

struct UserProfile: Decodable {
    let id: String
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
    let completedAt: String
}
