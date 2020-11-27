import Foundation


struct Release: Codable, Equatable {
    var createdAt: Date
    var description: String
    var isDraft: Bool
    var publishedAt: Date
    var tagName: String
    var url: String
}
