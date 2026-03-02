import Foundation
import Observation

@Observable
final class AppState {
    var user: AuthResponse?
    var posts: [Post] = []
    var showAuth: Bool = false
    var isLoading: Bool = false
    var error: String?

    var isLoggedIn: Bool { user != nil }

    private static let userCacheKey = "spark_auth_user"

    init() {
        restoreSession()
    }

    func login(username: String, password: String) async {
        await authenticate {
            try await SparkAPI.shared.login(username: username, password: password)
        }
    }

    func register(username: String, email: String?, password: String) async {
        await authenticate {
            try await SparkAPI.shared.register(username: username, email: email, password: password)
        }
    }

    func logout() {
        SparkAPI.shared.clearToken()
        KeychainHelper.delete(key: Self.userCacheKey)
        user = nil
        posts = []
    }

    func loadPosts() async {
        do {
            posts = try await SparkAPI.shared.fetchPosts()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createPost(title: String, content: String, category: String) async throws {
        let post = try await SparkAPI.shared.createPost(title: title, content: content, category: category)
        posts.insert(post, at: 0)
    }

    func vote(postId: String, type: String) async {
        do {
            try await SparkAPI.shared.vote(postId: postId, type: type)
            await loadPosts()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private

    private func restoreSession() {
        guard let token = SparkAPI.shared.loadToken(), !token.isEmpty else { return }
        guard let data = KeychainHelper.load(key: Self.userCacheKey),
              let saved = try? JSONDecoder().decode(AuthResponse.self, from: data) else { return }
        user = saved
    }

    private func authenticate(_ action: () async throws -> AuthResponse) async {
        isLoading = true
        error = nil
        do {
            let auth = try await action()
            user = auth
            persistUser(auth)
            showAuth = false
            await loadPosts()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func persistUser(_ auth: AuthResponse) {
        if let data = try? JSONEncoder().encode(auth) {
            KeychainHelper.save(key: Self.userCacheKey, data: data)
        }
    }
}
