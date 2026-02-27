import Foundation

struct AuthResponse: Codable {
    let token: String
    let username: String
    let userId: String
}
