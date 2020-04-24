import Vapor

let masterPackageListURL = URI(string: "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json")

enum IngestorError: Error {
    case recordNotFound
}

struct IngestorCommand: Command {
    struct Signature: CommandSignature { }

    var help: String {
        "Ingests packages"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        context.console.print("Ingesting ...")
        let masterList = try fetchMasterPackageList(context)
        let currentList = try fetchCurrentPackageList(context)

        let requests = masterList.and(currentList)
            .flatMap { (master, current) -> EventLoopFuture<Void> in
                let (toAdd, toDelete) = self.diff(source: master, target: current)
                let insertions = context.application.db.withConnection { db in
                    toAdd.map { Package(url: $0) }
                        .map { $0.create(on: db) }
                        .flatten(on: db.eventLoop)
                }
                let deletions: EventLoopFuture<Void> = context.application.db.withConnection { db in
                    toDelete
                        .map { url in
                            Package.query(on: db)
                                // TODO: outline this into a custom filer on Package
                                .filter("url", .equal, url.absoluteString)
                                .first()
                                .unwrap(or: IngestorError.recordNotFound)
                                .flatMap { pkg in
                                    pkg.delete(on: db)
                            }
                    }
                    .flatten(on: db.eventLoop)
                }
                return insertions.and(deletions).transform(to: ())
        }
        try requests.wait()
    }

    func fetchMasterPackageList(_ context: CommandContext) throws -> EventLoopFuture<[URL]> {
        context.application.client
                    .get(masterPackageListURL)
                    .flatMapThrowing {
                        try $0.content.decode([String].self, using: JSONDecoder())
        }
            // TODO: send error notification for failing URLs
        .flatMapEachCompactThrowing(URL.init(string:))
    }

    func fetchCurrentPackageList(_ context: CommandContext) throws -> EventLoopFuture<[URL]> {
        context.application.db.query(Package.self)
            .all()
            .mapEach(\.url)
            .mapEachCompact(URL.init(string:))
    }

    func diff(source: [URL], target: [URL]) -> (toAdd: Set<URL>, toDelete: Set<URL>) {
        let s = Set(source)
        let t = Set(target)
        return (toAdd: s.subtracting(t), toDelete: t.subtracting(s))
    }
}
