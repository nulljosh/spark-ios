import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case badResponse(Int)
    case decodingError(Error)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .badResponse(let code): return "Server returned \(code)"
        case .decodingError(let err): return "Decode error: \(err.localizedDescription)"
        case .serverError(let msg): return msg
        }
    }
}

final class SparkAPI: Sendable {
    static let shared = SparkAPI()

    private let baseURL = "https://spark.heyitsmejosh.com"
    private let tokenKey = "spark_jwt"

    private init() {}

    // MARK: - Token

    func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        KeychainHelper.save(key: tokenKey, data: data)
    }

    func loadToken() -> String? {
        guard let data = KeychainHelper.load(key: tokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clearToken() {
        KeychainHelper.delete(key: tokenKey)
    }

    // MARK: - Request helpers

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        return url
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil, auth: Bool = false) throws -> URLRequest {
        var req = URLRequest(url: try url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let token = loadToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        return req
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse(0) }
        guard (200...299).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["error"] as? String {
                throw APIError.serverError(msg)
            }
            throw APIError.badResponse(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performVoid(_ req: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse(0) }
        guard (200...299).contains(http.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["error"] as? String {
                throw APIError.serverError(msg)
            }
            throw APIError.badResponse(http.statusCode)
        }
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: ["username": username, "password": password])
        let req = try request("/api/auth/login", method: "POST", body: body)
        let result: AuthResponse = try await perform(req)
        saveToken(result.token)
        return result
    }

    func register(username: String, email: String?, password: String) async throws -> AuthResponse {
        var payload: [String: String] = ["username": username, "password": password]
        if let email = email, !email.isEmpty { payload["email"] = email }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try request("/api/auth/register", method: "POST", body: body)
        let result: AuthResponse = try await perform(req)
        saveToken(result.token)
        return result
    }

    // MARK: - Posts

    func fetchPosts() async throws -> [Post] {
        let req = try request("/api/posts")
        let result: PostsResponse = try await perform(req)
        return result.posts
    }

    func createPost(title: String, content: String, category: String) async throws -> Post {
        let payload = ["title": title, "content": content, "category": category]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try request("/api/posts", method: "POST", body: body, auth: true)
        return try await perform(req)
    }

    func vote(postId: String, type: String) async throws {
        let payload = ["voteType": type]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try request("/api/posts/\(postId)/vote", method: "POST", body: body, auth: true)
        try await performVoid(req)
    }
}

private struct PostsResponse: Decodable {
    let posts: [Post]
    let mode: String?
}
