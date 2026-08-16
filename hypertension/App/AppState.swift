import Combine
import Foundation

enum AppRouteState: Equatable {
    case checkingSession
    case signedOut
    case verifyEmail
    case profileSetup
    case mainApp
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var routeState: AppRouteState = .checkingSession
    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var currentProfile: UserProfile?
    @Published private(set) var requiredUpdate: RequiredAppUpdate?
    @Published var errorMessage: String?

    private let authService = AuthService()
    private let profileService = ProfileService()
    private let refreshTokenKey = "bphealth.refreshToken"
    private let deviceIdKey = "bphealth.deviceId"

    var currentEmail: String {
        currentUser?.email ?? ""
    }

    init() {
        APIClient.shared.setUpdateRequiredHandler { [weak self] requirement in
            self?.requiredUpdate = requirement
        }
        APIClient.shared.setAuthorizationRefreshHandler { [weak self] in
            guard let self else {
                throw APIClientError.sessionExpired
            }

            return try await self.refreshAuthorization()
        }
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
            if case APIClientError.updateRequired = error {
                return
            }
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
        currentProfile = profile
        routeState = .mainApp
    }

    func refreshProfile() async {
        guard currentUser?.profileCompleted == true else {
            currentProfile = nil
            return
        }

        do {
            currentProfile = try await profileService.fetchProfile().profile
        } catch {
            // Keep the last available profile so presentation remains stable offline.
        }
    }

    func logout() async {
        if let refreshToken = KeychainStore.read(refreshTokenKey) {
            try? await authService.logout(refreshToken: refreshToken)
        }

        clearLocalSession()
        routeState = .signedOut
    }

    #if DEBUG
    /// 仅供开发包使用：创建一个纯本地预览会话，方便无网络时查看 UI。
    /// 这个入口不会注册账号、登录后端或保存 refresh token。
    func enterDebugTestSession() async {
        clearLocalSession()

        let deviceToken = Self.debugDeviceToken(for: deviceId)
        currentUser = AuthUser(
            id: "local-preview-\(deviceToken)",
            email: Self.debugTestEmail(for: deviceId),
            emailVerified: true,
            profileCompleted: true
        )
        routeState = .mainApp
        APIClient.shared.accessToken = nil
    }

    static func debugTestEmail(for deviceId: String) -> String {
        let deviceToken = debugDeviceToken(for: deviceId)
        return "local-ui-preview-\(deviceToken)@bphealth.local"
    }

    private static func debugDeviceToken(for deviceId: String) -> String {
        deviceId
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
    #endif

    @discardableResult
    func deleteAccount(password: String) async -> String? {
        let deletedUserId = currentUser?.id
        do {
            try await authService.deleteAccount(password: password)
            if let deletedUserId {
                ActionHistoryStore.removeAll(userId: deletedUserId)
                try? GRDBLocalReadingStore.shared.clear(userId: deletedUserId)
                try? MealPhotoStore.shared.removeAll(userId: deletedUserId)
            }
            clearLocalSession()
            routeState = .signedOut
            return deletedUserId
        } catch {
            errorMessage = localizedMessage(for: error)
            return nil
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

    private func refreshAuthorization() async throws -> String {
        guard let refreshToken = KeychainStore.read(refreshTokenKey) else {
            clearLocalSession()
            routeState = .signedOut
            throw APIClientError.sessionExpired
        }

        do {
            let response = try await authService.refresh(refreshToken: refreshToken, deviceId: deviceId)
            try persistSession(response)
            routeByUser(response.user)
            return response.accessToken
        } catch {
            if shouldEndSession(afterRefreshError: error) {
                clearLocalSession()
                routeState = .signedOut
            }
            throw error
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

        routeState = Self.route(for: user)
    }

    static func route(for user: AuthUser) -> AppRouteState {
        if !user.emailVerified {
            return .verifyEmail
        }

        if !user.profileCompleted {
            return .profileSetup
        }

        return .mainApp
    }

    private func clearLocalSession() {
        APIClient.shared.accessToken = nil
        KeychainStore.delete(refreshTokenKey)
        currentUser = nil
        currentProfile = nil
        errorMessage = nil
    }

    private func shouldEndSession(afterRefreshError error: Error) -> Bool {
        guard case APIClientError.server(let code, _) = error else {
            return error is KeychainStoreError
        }

        return code == "INVALID_REFRESH_TOKEN" || code == "UNAUTHORIZED"
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
            case "VALIDATION_FAILED":
                return "邮箱或密码格式不符合要求。"
            default:
                return "服务器返回错误：\(code)。"
            }
        }

        if error is KeychainStoreError {
            return "登录信息保存失败，请重试。"
        }

        if error is DecodingError {
            return "服务器返回格式与 app 暂时不匹配。"
        }

        if error is URLError {
            return "网络连接失败，请检查网络后重试。"
        }

        return "网络或服务器暂时不可用。"
    }
}
