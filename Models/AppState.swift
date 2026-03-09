import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var user: AuthResponse?
    var posts: [Post] = []
    var showAuth: Bool = false
    var isLoading: Bool = false
    var isFeedLoading: Bool = false
    var error: String?
    var errorBanner: String?

    var isLoggedIn: Bool { user != nil }

    private(set) var votingPostIds: Set<String> = []

    private static let userCacheKey = "spark_auth_user"
    private var lastVoteTimes: [String: Date] = [:]
    private let voteDebounceInterval: TimeInterval = 0.5

    private var unauthorizedObserver: (any NSObjectProtocol)?

    let api: SparkAPIProtocol

    init(api: SparkAPIProtocol = SparkAPI.shared) {
        self.api = api
        restoreSession()
        observeUnauthorized()
    }

    private func observeUnauthorized() {
        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: SparkAPI.unauthorizedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleUnauthorized()
            }
        }
    }

    private func handleUnauthorized() {
        api.clearToken()
        KeychainHelper.delete(key: Self.userCacheKey)
        user = nil
        posts = []
        showAuth = true
        errorBanner = "Session expired. Please sign in again."
    }

    func login(username: String, password: String) async {
        await authenticate {
            try await self.api.login(username: username, password: password)
        }
    }

    func register(username: String, email: String?, password: String) async {
        await authenticate {
            try await self.api.register(username: username, email: email, password: password)
        }
    }

    func logout() {
        api.clearToken()
        KeychainHelper.delete(key: Self.userCacheKey)
        user = nil
        posts = []
        errorBanner = nil
    }

    func loadPosts() async {
        isFeedLoading = true
        do {
            posts = try await api.fetchPosts()
            errorBanner = nil
        } catch let apiError as APIError where apiError == .unauthorized {
            // handled by notification observer
        } catch {
            errorBanner = error.localizedDescription
        }
        isFeedLoading = false
    }

    func createPost(title: String, content: String, category: String) async throws {
        let post = try await api.createPost(title: title, content: content, category: category)
        posts.insert(post, at: 0)
    }

    func deletePost(id: String) async throws {
        try await api.deletePost(id: id)
        posts.removeAll { $0.id == id }
    }

    func vote(postId: String, type: String) async {
        // Debounce rapid taps
        let now = Date()
        if let last = lastVoteTimes[postId], now.timeIntervalSince(last) < voteDebounceInterval {
            return
        }
        lastVoteTimes[postId] = now

        guard !votingPostIds.contains(postId) else { return }
        votingPostIds.insert(postId)

        // Optimistic update
        let originalPosts = posts
        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            let delta = type == "up" ? 1 : -1
            let old = posts[idx]
            posts[idx] = Post(
                id: old.id,
                title: old.title,
                content: old.content,
                category: old.category,
                score: old.score + delta,
                author: old.author,
                createdAt: old.createdAt
            )
        }

        do {
            try await api.vote(postId: postId, type: type)
        } catch let apiError as APIError where apiError == .unauthorized {
            posts = originalPosts
        } catch {
            // Revert optimistic update
            posts = originalPosts
            self.errorBanner = error.localizedDescription
        }

        votingPostIds.remove(postId)
    }

    func dismissError() {
        errorBanner = nil
    }

    // MARK: - Private

    private func restoreSession() {
        guard let token = api.loadToken(), !token.isEmpty else { return }
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
