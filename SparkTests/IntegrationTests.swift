import XCTest
@testable import Spark

/// Integration tests that hit the real Spark API.
/// Skipped unless TestConfig.local.swift provides real credentials.
final class IntegrationTests: XCTestCase {

    private var api: SparkAPI!

    override func setUp() {
        super.setUp()
        // Trigger credential loading if TestConfig.local.swift exists
        _ = TestConfig.hasRealCredentials
        api = SparkAPI.shared
    }

    func testLoginCreateDeleteFlow() async throws {
        try XCTSkipUnless(TestConfig.hasRealCredentials, "No real credentials configured")

        // 1. Login
        let auth = try await api.login(username: TestConfig.username, password: TestConfig.password)
        XCTAssertFalse(auth.token.isEmpty)
        XCTAssertEqual(auth.username, TestConfig.username)

        // 2. Create a test post
        let title = "Integration Test \(Int(Date().timeIntervalSince1970))"
        let post = try await api.createPost(title: title, content: "Auto-generated integration test post. Safe to delete.", category: "Other")
        XCTAssertFalse(post.id.isEmpty)
        XCTAssertEqual(post.title, title)

        // 3. Verify post appears in feed
        let posts = try await api.fetchPosts()
        let found = posts.contains { $0.id == post.id }
        XCTAssertTrue(found, "Created post should appear in feed")

        // 4. Delete the test post (cleanup)
        try await api.deletePost(id: post.id)

        // 5. Verify post is gone
        let postsAfter = try await api.fetchPosts()
        let stillExists = postsAfter.contains { $0.id == post.id }
        XCTAssertFalse(stillExists, "Deleted post should not appear in feed")
    }
}
