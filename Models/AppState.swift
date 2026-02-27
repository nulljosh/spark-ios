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

    init() {
        checkAuth()
    }

    func checkAuth() {
        guard let token = SparkAPI.shared.loadToken(), !token.isEmpty else { return }
        // Restore lightweight session from Keychain — token is already stored,
        // decode username/userId from a cached AuthResponse if present.
        if let data = KeychainHelper.load(key: "spark_auth_user"),
           let saved = try? JSONDecoder().decode(AuthResponse.self, from: data) {
            user = saved
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        error = nil
        do {
            let auth = try await SparkAPI.shared.login(username: username, password: password)
            user = auth
            persistUser(auth)
            showAuth = false
            await loadPosts()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func register(username: String, email: String?, password: String) async {
        isLoading = true
        error = nil
        do {
            let auth = try await SparkAPI.shared.register(username: username, email: email, password: password)
            user = auth
            persistUser(auth)
            showAuth = false
            await loadPosts()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        SparkAPI.shared.clearToken()
        KeychainHelper.delete(key: "spark_auth_user")
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

    private func persistUser(_ auth: AuthResponse) {
        if let data = try? JSONEncoder().encode(auth) {
            KeychainHelper.save(key: "spark_auth_user", data: data)
        }
    }
}
