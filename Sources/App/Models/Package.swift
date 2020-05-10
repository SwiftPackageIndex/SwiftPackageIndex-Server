import Fluent
import Vapor


enum Status: String, Codable {
    case ok
    case invalidUrl = "invalid_url"
    case notFound = "not_found"
    case metadataRequestFailed = "metadata_request_failed"
    case ingestionFailed = "ingestion_failed"
    case analysisFailed = "analysis_failed"
}


enum ProcessingStage: String, Codable {
    case reconciliation
    case ingestion
    case analysis
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

    @OptionalEnum(key: "status")
    var status: Status?

    @OptionalEnum(key: "processing_stage")
    var processingStage: ProcessingStage?

    @Field(key: "last_commit_at")  // TODO: shouldn't this rather live in Repository? Is it needed at all?
    var lastCommitAt: Date?

    @Children(for: \.$package)
    var repositories: [Repository]

    @Children(for: \.$package)
    var versions: [Version]

    init() { }

    init(id: UUID? = nil,
         url: URL,
         status: Status? = nil,
         processingStage: ProcessingStage? = nil,
         lastCommitAt: Date? = nil) {
        self.id = id
        self.url = url.absoluteString
        self.status = status
        self.processingStage = processingStage
        self.lastCommitAt = lastCommitAt
    }
}


extension Package {
    var repository: Repository? {
        repositories.first
    }
}


extension Package {
    /// Cache directory basename, i.e. this is intended to be appended to
    /// the path of a directory where all checkouts are cached.
    var cacheDirectoryName: String? {
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
    static func fetchCandidates(_ database: Database,
                                for stage: ProcessingStage,
                                limit: Int) -> EventLoopFuture<[Package]> {
        Package.query(on: database)
            .with(\.$repositories)
            .filter(for: stage)
            .sort(.sql(raw: "status!='ok'"))
            .sort(\.$updatedAt)
            .limit(limit)
            .all()
    }
}


private extension QueryBuilder where Model == Package {
    func filter(for stage: ProcessingStage) -> Self {
        switch stage {
            case .reconciliation:
                fatalError("reconciliation stage does not select candidates")
            case .ingestion:
                return group(.or) {
                    $0.filter(\.$processingStage == .reconciliation)
                    .filter(\.$updatedAt < Current.date().addingTimeInterval(-Constants.reingestionDeadtime))
                }
            case .analysis:
                return filter(\.$processingStage == .ingestion)
        }
    }
}
