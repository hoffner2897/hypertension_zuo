import Foundation

struct APIErrorResponse: Decodable {
    let code: String
    let message: String?
}

enum APIClientError: LocalizedError {
    case invalidURL
    case missingAccessToken
    case server(code: String, message: String?)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid server URL."
        case .missingAccessToken:
            "Missing access token."
        case .server(let code, let message):
            message ?? code
        case .unexpectedResponse:
            "Unexpected server response."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    var baseURL = URL(string: "https://bphealth-api-staging.onrender.com")!
    var accessToken: String?

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
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
        requiresAuth: Bool
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let accessToken else {
                throw APIClientError.missingAccessToken
            }

            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.unexpectedResponse
        }

        if httpResponse.statusCode == 204, Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIClientError.server(code: errorResponse.code, message: errorResponse.message)
            }

            throw APIClientError.unexpectedResponse
        }

        return try decoder.decode(Response.self, from: data)
    }
}

struct EmptyResponse: Decodable {}

private struct EmptyRequest: Encodable {}
