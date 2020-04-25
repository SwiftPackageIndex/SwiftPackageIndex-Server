import Fluent
import Vapor

final class Package: Model, Content {
    static let schema = "packages"
    
    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Field(key: "url")
    var url: String

    @Field(key: "last_commit_at")  // TODO: shouldn't this rather live in Repository?
    var lastCommitAt: Date?

    init() { }

    init(id: UUID? = nil, url: URL) {
        self.id = id
        self.url = url.absoluteString
    }
}


extension QueryBuilder where Model == Package {
    func filter(by url: URL) -> Self {
        filter("url", .equal, url.absoluteString)
    }
}
