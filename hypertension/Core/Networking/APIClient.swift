import Foundation

struct APIErrorResponse: Decodable {
    let code: String
    let message: String?
    let minimumBuild: Int?
    let updateURL: String?
}

struct RequiredAppUpdate: Equatable {
    let minimumBuild: Int
    let updateURL: URL?
}

enum APIClientError: LocalizedError {
    case invalidURL
    case missingAccessToken
    case sessionExpired
    case updateRequired(RequiredAppUpdate)
    case server(code: String, message: String?)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid server URL."
        case .missingAccessToken:
            "Missing access token."
        case .sessionExpired:
            "Your session has expired. Please sign in again."
        case .updateRequired:
            "A newer version of BPHealth is required."
        case .server(let code, let message):
            message ?? code
        case .unexpectedResponse:
            "Unexpected server response."
        }
    }
}

final class APIClient {
    typealias DataLoader = (URLRequest) async throws -> (Data, URLResponse)
    typealias AuthorizationRefreshHandler = () async throws -> String
    typealias UpdateRequiredHandler = @MainActor (RequiredAppUpdate) -> Void

    static let shared = APIClient()

    var baseURL = APIClient.configuredBaseURL()
    var accessToken: String?

    private let dataLoader: DataLoader
    private let buildNumber: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var authorizationRefreshHandler: AuthorizationRefreshHandler?
    private var authorizationRefreshTask: Task<String, Error>?
    private var updateRequiredHandler: UpdateRequiredHandler?

    private static func configuredBaseURL(bundle: Bundle = .main) -> URL {
        if let value = bundle.object(forInfoDictionaryKey: "BPHealthAPIBaseURL") as? String,
           !value.isEmpty,
           !value.contains("$("),
           let url = URL(string: value) {
            return url
        }

        return URL(string: "https://bphealth-api-staging.onrender.com")!
    }

    init(session: URLSession = .shared, bundle: Bundle = .main) {
        buildNumber = Self.configuredBuildNumber(bundle: bundle)
        dataLoader = { request in
            try await session.data(for: request)
        }
    }

    init(dataLoader: @escaping DataLoader, buildNumber: String = "0") {
        self.dataLoader = dataLoader
        self.buildNumber = buildNumber
    }

    func setAuthorizationRefreshHandler(_ handler: AuthorizationRefreshHandler?) {
        authorizationRefreshHandler = handler
        if handler == nil {
            authorizationRefreshTask?.cancel()
            authorizationRefreshTask = nil
        }
    }

    func setUpdateRequiredHandler(_ handler: UpdateRequiredHandler?) {
        updateRequiredHandler = handler
    }

    func get<Response: Decodable>(_ path: String, requiresAuth: Bool = false) async throws -> Response {
        try await request(path, method: "GET", body: EmptyRequest?.none, requiresAuth: requiresAuth)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body, requiresAuth: Bool = false) async throws -> Response {
        try await request(path, method: "POST", body: body, requiresAuth: requiresAuth)
    }

    func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body, requiresAuth: Bool = false) async throws -> Response {
        try await request(path, method: "PUT", body: body, requiresAuth: requiresAuth)
    }

    func patch<Body: Encodable, Response: Decodable>(_ path: String, body: Body, requiresAuth: Bool = false) async throws -> Response {
        try await request(path, method: "PATCH", body: body, requiresAuth: requiresAuth)
    }

    func delete<Body: Encodable>(_ path: String, body: Body, requiresAuth: Bool = false) async throws {
        let _: EmptyResponse = try await request(path, method: "DELETE", body: body, requiresAuth: requiresAuth)
    }

    private func request<Body: Encodable, Response: Decodable>(
        _ path: String,
        method: String,
        body: Body?,
        requiresAuth: Bool,
        allowsAuthorizationRecovery: Bool = true
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(buildNumber, forHTTPHeaderField: "X-BPHealth-Build")
        request.setValue(L10n.language.rawValue, forHTTPHeaderField: "Accept-Language")

        let requestAccessToken: String?
        if requiresAuth {
            guard let accessToken else {
                throw APIClientError.missingAccessToken
            }

            requestAccessToken = accessToken
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            requestAccessToken = nil
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await dataLoader(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.unexpectedResponse
        }

        if httpResponse.statusCode == 401, requiresAuth, allowsAuthorizationRecovery {
            let recoveredAccessToken: String
            if let requestAccessToken,
               let accessToken,
               accessToken != requestAccessToken {
                // Another in-flight request already refreshed the token while this
                // request was waiting for its response.
                recoveredAccessToken = accessToken
            } else {
                recoveredAccessToken = try await refreshAuthorization()
            }

            accessToken = recoveredAccessToken
            return try await self.request(
                path,
                method: method,
                body: body,
                requiresAuth: requiresAuth,
                allowsAuthorizationRecovery: false
            )
        }

        if httpResponse.statusCode == 204, Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        if httpResponse.statusCode == 426,
           let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data),
           errorResponse.code == "UPDATE_REQUIRED" {
            let requirement = RequiredAppUpdate(
                minimumBuild: errorResponse.minimumBuild ?? 0,
                updateURL: errorResponse.updateURL.flatMap(URL.init(string:))
            )
            if let updateRequiredHandler {
                await updateRequiredHandler(requirement)
            }
            throw APIClientError.updateRequired(requirement)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIClientError.server(code: errorResponse.code, message: errorResponse.message)
            }

            throw APIClientError.unexpectedResponse
        }

        return try decoder.decode(Response.self, from: data)
    }

    private func refreshAuthorization() async throws -> String {
        if let authorizationRefreshTask {
            return try await authorizationRefreshTask.value
        }

        guard let authorizationRefreshHandler else {
            throw APIClientError.sessionExpired
        }

        let task = Task {
            try await authorizationRefreshHandler()
        }
        authorizationRefreshTask = task

        do {
            let accessToken = try await task.value
            authorizationRefreshTask = nil
            return accessToken
        } catch {
            authorizationRefreshTask = nil
            throw error
        }
    }

    private static func configuredBuildNumber(bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

struct EmptyResponse: Decodable {}

private struct EmptyRequest: Encodable {}
