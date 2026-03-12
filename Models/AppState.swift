import Foundation
import Observation
import LocalAuthentication

@MainActor
@Observable
final class AppState {
    private enum BiometricConstants {
        static let savedUsernameKey = "spark_saved_username"
    }

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
        } onSuccess: {
            self.saveBiometricCredentials(username: username, password: password)
        }
    }

    func register(username: String, email: String?, password: String) async {
        await authenticate {
            try await self.api.register(username: username, email: email, password: password)
        } onSuccess: {
            self.saveBiometricCredentials(username: username, password: password)
        }
    }

    func logout() {
        api.clearToken()
        KeychainHelper.delete(key: Self.userCacheKey)
        clearBiometricCredentials()
        user = nil
        posts = []
        errorBanner = nil
    }

    func biometricBiometryType() -> LABiometryType {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }
        return context.biometryType
    }

    func hasSavedBiometricCredentials() -> Bool {
        guard let username = UserDefaults.standard.string(forKey: BiometricConstants.savedUsernameKey) else {
            return false
        }
        return KeychainHelper.load(key: username) != nil
    }

    func biometricLogin() async {
        error = nil

        let context = LAContext()
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Sign in to Spark")
            guard let credentials = loadBiometricCredentials() else {
                error = "No saved credentials found"
                return
            }
            await login(username: credentials.username, password: credentials.password)
        } catch {
            self.error = error.localizedDescription
        }
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

    private func authenticate(
        _ action: () async throws -> AuthResponse,
        onSuccess: @escaping () -> Void = {}
    ) async {
        isLoading = true
        error = nil
        do {
            let auth = try await action()
            user = auth
            persistUser(auth)
            onSuccess()
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

    private func saveBiometricCredentials(username: String, password: String) {
        guard let passwordData = password.data(using: .utf8) else { return }
        UserDefaults.standard.set(username, forKey: BiometricConstants.savedUsernameKey)
        KeychainHelper.save(key: username, data: passwordData)
    }

    private func loadBiometricCredentials() -> (username: String, password: String)? {
        guard let username = UserDefaults.standard.string(forKey: BiometricConstants.savedUsernameKey),
              let data = KeychainHelper.load(key: username),
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return (username, password)
    }

    private func clearBiometricCredentials() {
        if let username = UserDefaults.standard.string(forKey: BiometricConstants.savedUsernameKey) {
            KeychainHelper.delete(key: username)
        }
        UserDefaults.standard.removeObject(forKey: BiometricConstants.savedUsernameKey)
    }
}
