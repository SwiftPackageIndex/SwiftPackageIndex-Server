import Vapor
import Fluent


enum IngestorError: Error {
    case invalidPackageUrl
    case requestFailed(HTTPStatus)
}


enum Github {
    struct License: Decodable {
        var key: String
    }
    struct Parent: Decodable {
        var cloneUrl: String
        var fullName: String
        var url: String
    }
    struct Metadata: Decodable {
        var defaultBranch: String
        var description: String?
        var forksCount: Int
        var license: License?
        var stargazersCount: Int
        var parent: Parent?
    }

    static func fetchRepository(client: Client, package: Package) throws -> EventLoopFuture<Metadata> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let url = try apiUri(for: package)
        let request = client
            .get(url, headers: getHeaders)
            .flatMapThrowing { response -> Metadata in
                guard response.status == .ok else { throw IngestorError.requestFailed(response.status) }
                return try response.content.decode(Metadata.self, using: decoder)
        }
        return request
    }

    static var getHeaders: HTTPHeaders {
        // Set User-Agent or we get a 403
        // https://developer.github.com/v3/#user-agent-required
        .init([("User-Agent", "SPI-Server")])
    }

    static func apiUri(for package: Package) throws -> URI {
        let githubPrefix = "https://github.com/"
        let gitSuffix = ".git"
        guard package.url.hasPrefix(githubPrefix) else { throw IngestorError.invalidPackageUrl }
        var url = package.url.dropFirst(githubPrefix.count)
        if url.hasSuffix(gitSuffix) { url = url.dropLast(gitSuffix.count) }
        return URI(string: "https://api.github.com/repos/\(url)")
    }
}


struct IngestorCommand: Command {
    let defaultLimit = 2

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?
    }

    var help: String {
        "Ingests packages"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        context.console.print("Ingesting (limit: \(limit)) ...")

        // for selected packages:
        // - fetch meta data
        // - create/update repository

        let db = context.application.db
        let client = context.application.client

        let metaDataFutures = Package.query(on: db)
            .limit(limit)
            .all()
            .flatMapEachThrowing { try Github.fetchRepository(client: client, package: $0).and(value: $0) }
            .flatMap { $0.flatten(on: db.eventLoop) }
        let updates = metaDataFutures
            .flatMapEachThrowing { (ghRepo, pkg) -> EventLoopFuture<Void> in
                try insertOrUpdateRepository(on: db, for: pkg, metadata: ghRepo)
        }
        .flatMap { $0.flatten(on: db.eventLoop) }

        try updates.wait()
    }

}


func insertOrUpdateRepository(on db: Database, for package: Package, metadata: Github.Metadata) throws -> EventLoopFuture<Void> {
    // TODO: fetch existing
    try Repository(package: package, metadata: metadata)
        .create(on: db)
}


