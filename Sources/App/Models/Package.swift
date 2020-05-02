import Fluent
import Vapor


enum Status: String, Codable {
    case none
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

    @Enum(key: "status")
    var status: Status

    @Field(key: "last_commit_at")  // TODO: shouldn't this rather live in Repository?
    var lastCommitAt: Date?

    @Children(for: \.$package)
    var repositories: [Repository]

    @Children(for: \.$package)
    var versions: [Version]

    init() { }

    init(id: UUID? = nil, url: URL, status: Status = .none) {
        self.id = id
        self.url = url.absoluteString
        self.status = status
    }
}


extension Package {
    var repository: Repository? {
        repositories.first
    }
}


extension Package {
    var defaultVersion: Version? {
        // TODO: sas 2020-04-30: find a more convenient way to use this. In order to avoid
        // fatalErrors from lack of lazy loading, the caller needs to use it on a Package that's
        // been fetched like so:
        //   Package.query(on: db).with(\.$versions).with(\.$repositories)
        // That's awkward. Should instead defaultBranch take a parameter (on: db) and do this
        // itself?
        guard let defaultBranch = repository?.defaultBranch else { return nil }
        return versions.first(where: { $0.branchName == defaultBranch })
    }
}


extension Package {
    var localCacheDirectory: String? {
        URL(string: url).flatMap {
            guard let host = $0.host, !host.isEmpty else { return nil }
            let trunk = $0.path
                .replacingOccurrences(of: "/", with: "-")
                .lowercased()
                .droppingGitExtension
            guard !trunk.isEmpty else { return nil }
            return trunk.hasPrefix("-")
                ? host + trunk
                : host + "-" + trunk
        }
    }
}


extension QueryBuilder where Model == Package {
    func filter(by url: URL) -> Self {
        filter(\.$url == url.absoluteString)
    }
}


extension Package {
    static func fetchUpdateCandidates(_ database: Database, limit: Int) -> EventLoopFuture<[Package]> {
        Package.query(on: database)
            // TODO: filter out updated in last X minutes
            .sort(\.$updatedAt)
            .limit(limit)
            .all()
    }
}
