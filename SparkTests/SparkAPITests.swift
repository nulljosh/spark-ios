import XCTest
@testable import Spark

final class SparkAPITests: XCTestCase {

    func testAPIErrorDescriptions() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(APIError.badResponse(404).errorDescription, "Server returned 404")
        XCTAssertEqual(APIError.unauthorized.errorDescription, "Session expired. Please sign in again.")
        XCTAssertEqual(APIError.rateLimited.errorDescription, "Too many requests. Try again shortly.")
        XCTAssertEqual(APIError.serverError("oops").errorDescription, "oops")
    }

    func testAPIErrorEquatable() {
        XCTAssertEqual(APIError.unauthorized, APIError.unauthorized)
        XCTAssertEqual(APIError.rateLimited, APIError.rateLimited)
        XCTAssertEqual(APIError.badResponse(404), APIError.badResponse(404))
        XCTAssertNotEqual(APIError.badResponse(404), APIError.badResponse(500))
        XCTAssertNotEqual(APIError.unauthorized, APIError.rateLimited)
    }

    func testProtocolConformance() {
        let api: any SparkAPIProtocol = SparkAPI.shared
        XCTAssertNotNil(api)
    }
}
