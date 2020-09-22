import Vapor
import SotoS3


struct MigrateLogsCommand: Command {
    let defaultLimit = 1

    struct Signature: CommandSignature {
        @Option(name: "limit", short: "l")
        var limit: Int?

        @Option(name: "id", help: "build id")
        var id: Build.Id?
    }

    var help: String { "Migate logs to S3" }

    func run(using context: CommandContext, signature: Signature) throws {
        let limit = signature.limit ?? defaultLimit
        if let id = signature.id {
            context.console.info("Migrating logs (build id: \(id)) ...")
            try migrateLogs(application: context.application, id: id).wait()
        } else {
            context.console.info("Migrating logs (limit: \(limit)) ...")
            try migrateLogs(application: context.application, limit: limit).wait()
        }
    }

}


func migrateLogs(application: Application, id: Build.Id) -> EventLoopFuture<Void> {
    Build.find(id, on: application.db)
        .unwrap(or: Abort(.notFound))
        .flatMap {
            migrateLogs(application: application, builds: [$0])
        }
}


func migrateLogs(application: Application, limit: Int) -> EventLoopFuture<Void> {
    fetchMigrationCandidates(application: application, limit: limit)
        .flatMap { migrateLogs(application: application, builds: $0)}
}


func migrateLogs(application: Application, builds: [Build]) -> EventLoopFuture<Void> {
    builds.map { build in
        guard let logs = build.logs else {
            return application.eventLoopGroup.future()
        }
        let key = LogStore.Key()
        return LogStore.save(logs: logs, key: key)
            .map { key.url }
            .flatMap {
                build.logUrl = $0
                return build.update(on: application.db)
            }
    }
    .flatten(on: application.eventLoopGroup.next())
}


func fetchMigrationCandidates(application: Application, limit: Int) -> EventLoopFuture<[Build]> {
    // FIXME: implement
    application.eventLoopGroup.future([])
}


enum LogStore {
    enum Error: Swift.Error {
        case encodingError
    }

    static private let region: SotoS3.Region = .useast2
    static private let bucket = "spi-build-logs"
    static private let s3 = S3(client: client, region: region)

    static private let client = AWSClient(
        credentialProvider: .static(
            accessKeyId: Environment.get("AWS_ACCESS_KEY_ID")!,
            secretAccessKey: Environment.get("AWS_SECRET_ACCESS_KEY")!
        ),
        httpClientProvider: .createNew
    )

    static func save(logs: String, key: Key) -> EventLoopFuture<Void> {
        guard let data = logs.data(using: .utf8) else {
            return s3.eventLoopGroup.future(error: Error.encodingError)
        }
        let payload = AWSPayload.data(data)
        let req = S3.PutObjectRequest(
            acl: .publicRead,  // requires "Block all public access" to be "off"
            body: payload,
            bucket: bucket,
            key: key.filename
        )
        return s3.putObject(req).transform(to: ())
    }

    struct Key {
        let id = UUID()

        var filename: String { "\(id.uuidString).log" }
        var url: String { "https://\(LogStore.bucket).s3.\(LogStore.region.rawValue).\(LogStore.region.partition.dnsSuffix)/\(filename)" }
    }
}
