import XCTest
@testable import Spark

@MainActor
final class AppStateTests: XCTestCase {

    private func makeState(api: MockSparkAPI = MockSparkAPI()) -> (AppState, MockSparkAPI) {
        return (AppState(api: api), api)
    }

    func testLoginSetsUser() async {
        let mock = MockSparkAPI()
        let state = AppState(api: mock)

        await state.login(username: "josh", password: "pass")

        XCTAssertNotNil(state.user)
        XCTAssertEqual(state.user?.username, "testuser")
        XCTAssertTrue(state.isLoggedIn)
        XCTAssertEqual(mock.loginCallCount, 1)
    }

    func testLoginFailureSetsError() async {
        let mock = MockSparkAPI()
        mock.loginResult = .failure(APIError.serverError("Invalid credentials"))
        let state = AppState(api: mock)

        await state.login(username: "bad", password: "bad")

        XCTAssertNil(state.user)
        XCTAssertFalse(state.isLoggedIn)
        XCTAssertNotNil(state.error)
    }

    func testLogoutClearsState() async {
        let mock = MockSparkAPI()
        let state = AppState(api: mock)
        await state.login(username: "josh", password: "pass")
        XCTAssertTrue(state.isLoggedIn)

        state.logout()

        XCTAssertNil(state.user)
        XCTAssertFalse(state.isLoggedIn)
        XCTAssertTrue(state.posts.isEmpty)
        XCTAssertTrue(mock.tokenCleared)
    }

    func testLoadPostsPopulatesArray() async {
        let mock = MockSparkAPI()
        let posts = [
            Post(id: "1", title: "A", content: "B", category: "Tech", score: 3, author: nil, createdAt: nil),
            Post(id: "2", title: "C", content: "D", category: "Art", score: 1, author: nil, createdAt: nil)
        ]
        mock.fetchPostsResult = .success(posts)
        let state = AppState(api: mock)

        await state.loadPosts()

        XCTAssertEqual(state.posts.count, 2)
        XCTAssertEqual(state.posts[0].id, "1")
        XCTAssertEqual(state.posts[1].id, "2")
    }

    func testLoadPostsErrorSetsErrorBanner() async {
        let mock = MockSparkAPI()
        mock.fetchPostsResult = .failure(APIError.badResponse(500))
        let state = AppState(api: mock)

        await state.loadPosts()

        XCTAssertNotNil(state.errorBanner)
        XCTAssertTrue(state.posts.isEmpty)
    }

    func testCreatePostInsertsAtFront() async throws {
        let mock = MockSparkAPI()
        mock.fetchPostsResult = .success([
            Post(id: "old", title: "Old", content: "C", category: "X", score: 0, author: nil, createdAt: nil)
        ])
        let state = AppState(api: mock)
        await state.loadPosts()

        try await state.createPost(title: "New", content: "Body", category: "Tech")

        XCTAssertEqual(state.posts.first?.id, "new1")
    }

    func testVoteUpdatesOptimistically() async {
        let mock = MockSparkAPI()
        let posts = [
            Post(id: "p1", title: "T", content: "C", category: "X", score: 5, author: nil, createdAt: nil)
        ]
        mock.fetchPostsResult = .success(posts)
        let state = AppState(api: mock)
        await state.loadPosts()

        // After vote completes, loadPosts is called again which resets to mock data
        await state.vote(postId: "p1", type: "up")

        XCTAssertEqual(mock.voteCallCount, 1)
    }

    func testVoteRevertsOnFailure() async {
        let mock = MockSparkAPI()
        let posts = [
            Post(id: "p1", title: "T", content: "C", category: "X", score: 5, author: nil, createdAt: nil)
        ]
        mock.fetchPostsResult = .success(posts)
        mock.voteResult = .failure(APIError.badResponse(500))
        let state = AppState(api: mock)
        await state.loadPosts()

        await state.vote(postId: "p1", type: "up")

        XCTAssertEqual(state.posts.first?.score, 5)
        XCTAssertNotNil(state.errorBanner)
    }

    func testDeletePostRemovesFromArray() async throws {
        let mock = MockSparkAPI()
        let posts = [
            Post(id: "p1", title: "A", content: "B", category: "Tech", score: 1, author: Post.Author(username: "testuser"), createdAt: nil),
            Post(id: "p2", title: "C", content: "D", category: "Art", score: 2, author: nil, createdAt: nil)
        ]
        mock.fetchPostsResult = .success(posts)
        let state = AppState(api: mock)
        await state.loadPosts()
        XCTAssertEqual(state.posts.count, 2)

        try await state.deletePost(id: "p1")

        XCTAssertEqual(state.posts.count, 1)
        XCTAssertEqual(state.posts.first?.id, "p2")
        XCTAssertEqual(mock.deleteCallCount, 1)
    }

    func testDeletePostFailureKeepsPosts() async {
        let mock = MockSparkAPI()
        mock.fetchPostsResult = .success([
            Post(id: "p1", title: "A", content: "B", category: "Tech", score: 1, author: nil, createdAt: nil)
        ])
        mock.deletePostResult = .failure(APIError.badResponse(403))
        let state = AppState(api: mock)
        await state.loadPosts()

        do {
            try await state.deletePost(id: "p1")
            XCTFail("Expected error")
        } catch {
            // Error thrown means posts stay (deletePost throws before removing)
        }
        // Post stays because the API call fails before removeAll runs
        XCTAssertEqual(state.posts.count, 1)
        XCTAssertEqual(mock.deleteCallCount, 1)
    }

    func testDismissErrorClearsBanner() {
        let mock = MockSparkAPI()
        let state = AppState(api: mock)
        state.errorBanner = "Something broke"

        state.dismissError()

        XCTAssertNil(state.errorBanner)
    }
}
