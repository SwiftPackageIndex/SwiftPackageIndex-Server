import Foundation


struct Release: Codable, Equatable {
    var description: String?
    var isDraft: Bool
    var publishedAt: Date?
    var tagName: String
    var url: String
}


extension Release {
    init(from node: Github.Metadata.ReleaseNodes.ReleaseNode) {
        description = node.descriptionHTML
        isDraft = node.isDraft
        publishedAt = node.publishedAt
        tagName = node.tagName
        url = node.url
    }
}
