import Fluent
import Vapor


enum Status: String, Codable {
    case ok
    case invalidUrl = "invalid_url"
    case notFound = "not_found"
    case metadataRequestFailed = "metadata_request_failed"
    case ingestionFailed = "ingestion_failed"
}


final class Package: Model, Content {
    static let schema = "packages"

    typealias Id = UUID

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Field(key: "url")
    var url: String

    @Field(key: "status")
    var status: Status?

    @Field(key: "last_commit_at")  // TODO: shouldn't this rather live in Repository?
    var lastCommitAt: Date?

    init() { }

    init(id: UUID? = nil, url: URL, status: Status? = nil) {
        self.id = id
        self.url = url.absoluteString
        self.status = status
    }
}


extension QueryBuilder where Model == Package {
    func filter(by url: URL) -> Self {
        filter(\.$url == url.absoluteString)
    }
}


extension QueryBuilder where Model == Package {
    func ingestionBatch(limit: Int) -> EventLoopFuture<[Package]> {
        sort(\.$updatedAt)
        .limit(limit)
        .all()
    }
}
