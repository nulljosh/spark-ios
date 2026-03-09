import XCTest
@testable import Spark

final class AuthResponseTests: XCTestCase {

    func testDecodeValidAuthResponse() throws {
        let json = """
        {
            "token": "jwt.token.here",
            "username": "josh",
            "userId": "user_123"
        }
        """.data(using: .utf8)!

        let auth = try JSONDecoder().decode(AuthResponse.self, from: json)
        XCTAssertEqual(auth.token, "jwt.token.here")
        XCTAssertEqual(auth.username, "josh")
        XCTAssertEqual(auth.userId, "user_123")
    }

    func testDecodeMissingFieldThrows() {
        let json = """
        {"token": "abc", "username": "josh"}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(AuthResponse.self, from: json))
    }

    func testRoundTrip() throws {
        let original = AuthResponse(token: "tok", username: "user", userId: "uid")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        XCTAssertEqual(decoded.token, original.token)
        XCTAssertEqual(decoded.username, original.username)
        XCTAssertEqual(decoded.userId, original.userId)
    }
}
