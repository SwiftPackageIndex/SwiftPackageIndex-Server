import Fluent
import Vapor


enum Status: String, Codable {
    case ok
    case new
    // errors
    case analysisFailed = "analysis_failed"
    case ingestionFailed = "ingestion_failed"
    case invalidCachePath = "invalid_cache_path"
    case invalidUrl = "invalid_url"
    case metadataRequestFailed = "metadata_request_failed"
    case notFound = "not_found"
    case noValidVersions = "no_valid_versions"
    case shellCommandFailed = "shell_command_failed"
}


enum ProcessingStage: String, Codable {
    case reconciliation
    case ingestion
    case analysis
}


final class Package: Model, Content {
    static let schema = "packages"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // data fields

    @OptionalEnum(key: "processing_stage")
    var processingStage: ProcessingStage?

    @Field(key: "score")
    var score: Int?

    @Enum(key: "status")
    var status: Status

    @Field(key: "url")
    var url: String
    
    // relationships

    @Children(for: \.$package)
    var repositories: [Repository]

    @Children(for: \.$package)
    var versions: [Version]

    init() { }

    init(id: UUID? = nil,
         url: URL,
         score: Int? = nil,
         status: Status = .new,
         processingStage: ProcessingStage? = nil) {
        self.id = id
        self.url = url.absoluteString
        self.score = score
        self.status = status
        self.processingStage = processingStage
    }
}


extension Package {
    var repository: Repository? {
        guard let repositories = $repositories.value else { return nil }
        return repositories.first
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
            .sort(.sql(raw: "status != 'new'"))
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
                    .filter(\.$updatedAt < Current.date().addingTimeInterval(-Constants.reIngestionDeadtime))
                }
            case .analysis:
                return filter(\.$processingStage == .ingestion)
        }
    }
}
