import Foundation


struct Release: Codable, Equatable {
    // FIXME: remove createdAt
    var createdAt: Date
    var description: String
    var isDraft: Bool
    var publishedAt: Date
    var tagName: String
    var url: String
}


extension Release {
    init(from node: Github.Metadata.ReleaseNodes.ReleaseNode) {
        createdAt = node.createdAt
        description = node.description
        isDraft = node.isDraft
        publishedAt = node.publishedAt
        tagName = node.tagName
        url = node.url
    }
}
