import Foundation

struct Post: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let content: String
    let category: String
    let score: Int
    let author: Author?
    let createdAt: String?

    struct Author: Codable, Hashable {
        let username: String
    }
}
