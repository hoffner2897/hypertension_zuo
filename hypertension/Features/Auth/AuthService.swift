import Foundation

struct AuthService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func register(email: String, password: String, deviceId: String?) async throws -> AuthResponse {
        try await apiClient.post("/auth/register", body: AuthRequest(email: email, password: password, deviceId: deviceId))
    }

    func login(email: String, password: String, deviceId: String?) async throws -> AuthResponse {
        try await apiClient.post("/auth/login", body: AuthRequest(email: email, password: password, deviceId: deviceId))
    }

    func refresh(refreshToken: String, deviceId: String?) async throws -> AuthResponse {
        try await apiClient.post("/auth/refresh", body: RefreshRequest(refreshToken: refreshToken, deviceId: deviceId))
    }

    func logout(refreshToken: String) async throws {
        let _: EmptyResponse = try await apiClient.post("/auth/logout", body: LogoutRequest(refreshToken: refreshToken))
    }

    func me() async throws -> MeResponse {
        try await apiClient.get("/auth/me", requiresAuth: true)
    }

    func verifyEmail(token: String) async throws -> VerifyEmailResponse {
        try await apiClient.post("/auth/verify-email", body: VerifyEmailRequest(token: token))
    }

    func resendVerification(email: String) async throws {
        let _: BasicOKResponse = try await apiClient.post("/auth/resend-verification", body: ResendVerificationRequest(email: email))
    }

    func deleteAccount(password: String) async throws {
        try await apiClient.delete("/auth/account", body: DeleteAccountRequest(password: password), requiresAuth: true)
    }
}

private struct AuthRequest: Encodable {
    let email: String
    let password: String
    let deviceId: String?
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
    let deviceId: String?
}

private struct LogoutRequest: Encodable {
    let refreshToken: String
}

private struct VerifyEmailRequest: Encodable {
    let token: String
}

private struct ResendVerificationRequest: Encodable {
    let email: String
}

private struct DeleteAccountRequest: Encodable {
    let password: String
}

private struct BasicOKResponse: Decodable {
    let ok: Bool
}
