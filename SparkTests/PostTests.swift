import XCTest
@testable import Spark

final class PostTests: XCTestCase {

    func testDecodeValidPost() throws {
        let json = """
        {
            "id": "abc123",
            "title": "Test Post",
            "content": "Some content",
            "category": "Tech",
            "score": 5,
            "author": {"username": "josh"},
            "createdAt": "2026-03-01T12:00:00.000Z"
        }
        """.data(using: .utf8)!

        let post = try JSONDecoder().decode(Post.self, from: json)
        XCTAssertEqual(post.id, "abc123")
        XCTAssertEqual(post.title, "Test Post")
        XCTAssertEqual(post.content, "Some content")
        XCTAssertEqual(post.category, "Tech")
        XCTAssertEqual(post.score, 5)
        XCTAssertEqual(post.author?.username, "josh")
        XCTAssertEqual(post.createdAt, "2026-03-01T12:00:00.000Z")
    }

    func testDecodePostMissingOptionalFields() throws {
        let json = """
        {
            "id": "abc123",
            "title": "Test",
            "content": "Body",
            "category": "Science",
            "score": 0
        }
        """.data(using: .utf8)!

        let post = try JSONDecoder().decode(Post.self, from: json)
        XCTAssertEqual(post.id, "abc123")
        XCTAssertNil(post.author)
        XCTAssertNil(post.createdAt)
    }

    func testDecodeMalformedPostThrows() {
        let json = """
        {"id": "abc", "title": 123}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(Post.self, from: json))
    }

    func testPostIdentifiable() throws {
        let json = """
        {"id": "unique1", "title": "T", "content": "C", "category": "X", "score": 0}
        """.data(using: .utf8)!

        let post = try JSONDecoder().decode(Post.self, from: json)
        XCTAssertEqual(post.id, "unique1")
    }
}
