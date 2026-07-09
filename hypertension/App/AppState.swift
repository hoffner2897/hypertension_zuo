import Combine
import Foundation

enum AppRouteState {
    case checkingSession
    case signedOut
    case profileSetup
    case mainApp
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var routeState: AppRouteState = .checkingSession
    @Published private(set) var currentUser: AuthUser?
    @Published var errorMessage: String?

    private let authService = AuthService()
    private let refreshTokenKey = "bphealth.refreshToken"
    private let deviceIdKey = "bphealth.deviceId"

    var currentEmail: String {
        currentUser?.email ?? ""
    }

    func bootstrap() async {
        guard let refreshToken = KeychainStore.read(refreshTokenKey) else {
            routeState = .signedOut
            return
        }

        do {
            let response = try await authService.refresh(refreshToken: refreshToken, deviceId: deviceId)
            try persistSession(response)
            routeByUser(response.user)
        } catch {
            clearLocalSession()
            routeState = .signedOut
        }
    }

    func register(email: String, password: String) async {
        await authenticate {
            try await authService.register(email: email, password: password, deviceId: deviceId)
        }
    }

    func login(email: String, password: String) async {
        await authenticate {
            try await authService.login(email: email, password: password, deviceId: deviceId)
        }
    }

    func verifyEmail(token: String) async {
        do {
            let response = try await authService.verifyEmail(token: token)
            currentUser = response.user
            routeByUser(response.user)
            errorMessage = nil
        } catch {
            errorMessage = localizedMessage(for: error)
        }
    }

    func resendVerification() async {
        guard let email = currentUser?.email else {
            return
        }

        do {
            try await authService.resendVerification(email: email)
            errorMessage = nil
        } catch {
            errorMessage = localizedMessage(for: error)
        }
    }

    func completeProfile(_ profile: UserProfile) {
        guard let currentUser else {
            routeState = .signedOut
            return
        }

        self.currentUser = AuthUser(
            id: currentUser.id,
            email: currentUser.email,
            emailVerified: currentUser.emailVerified,
            profileCompleted: true
        )
        routeState = .mainApp
    }

    func logout() async {
        if let refreshToken = KeychainStore.read(refreshTokenKey) {
            try? await authService.logout(refreshToken: refreshToken)
        }

        clearLocalSession()
        routeState = .signedOut
    }

    func deleteAccount(password: String) async {
        do {
            try await authService.deleteAccount(password: password)
            clearLocalSession()
            routeState = .signedOut
        } catch {
            errorMessage = localizedMessage(for: error)
        }
    }

    private func authenticate(_ action: () async throws -> AuthResponse) async {
        do {
            let response = try await action()
            try persistSession(response)
            routeByUser(response.user)
            errorMessage = nil
        } catch {
            errorMessage = localizedMessage(for: error)
        }
    }

    private func persistSession(_ response: AuthResponse) throws {
        APIClient.shared.accessToken = response.accessToken
        try KeychainStore.save(response.refreshToken, for: refreshTokenKey)
        try KeychainStore.save(response.deviceId, for: deviceIdKey)
        currentUser = response.user
    }

    private func routeByUser(_ user: AuthUser) {
        currentUser = user

        if !user.profileCompleted {
            routeState = .profileSetup
        } else {
            routeState = .mainApp
        }
    }

    private func clearLocalSession() {
        APIClient.shared.accessToken = nil
        KeychainStore.delete(refreshTokenKey)
        try? GRDBLocalReadingStore.shared.clearAll()
        currentUser = nil
        errorMessage = nil
    }

    private var deviceId: String {
        if let existing = KeychainStore.read(deviceIdKey) {
            return existing
        }

        let newValue = UUID().uuidString
        try? KeychainStore.save(newValue, for: deviceIdKey)
        return newValue
    }

    private func localizedMessage(for error: Error) -> String {
        if case APIClientError.server(let code, _) = error {
            switch code {
            case "EMAIL_ALREADY_REGISTERED":
                return "这个邮箱已经注册。"
            case "INVALID_CREDENTIALS":
                return "邮箱或密码不正确。"
            case "PASSWORD_CONFIRMATION_FAILED":
                return "密码确认失败。"
            default:
                return "操作失败，请稍后重试。"
            }
        }

        return "网络或服务器暂时不可用。"
    }
}
