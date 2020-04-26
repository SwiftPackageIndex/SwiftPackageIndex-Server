import Fluent
import Vapor


struct ReconcilerCommand: Command {
    struct Signature: CommandSignature { }

    var help: String { "Reconcile master package list with server" }

    func run(using context: CommandContext, signature: Signature) throws {
        context.console.print("Reconciling ...")
        let request = try reconcile(with: context.application.client,
                                    database: context.application.db)
        try request.wait()
    }
}


func reconcile(with client: Client, database: Database) throws -> EventLoopFuture<Void> {
    let masterList = try Current.fetchMasterPackageList(client)
    let currentList = try fetchCurrentPackageList(database)

    return masterList.and(currentList)
        .flatMap { reconcileLists(db: database, source: $0, target: $1) }
}


func liveFetchMasterPackageList(_ client: Client) throws -> EventLoopFuture<[URL]> {
    client
        .get(Constants.masterPackageListUri)
        .flatMapThrowing { try $0.content.decode([String].self, using: JSONDecoder()) }
        // TODO: send error notification for failing URLs
        .flatMapEachCompactThrowing(URL.init(string:))
}


func fetchCurrentPackageList(_ db: Database) throws -> EventLoopFuture<[URL]> {
    db.query(Package.self)
        .all()
        .mapEach(\.url)
        .mapEachCompact(URL.init(string:))
}


func diff(source: [URL], target: [URL]) -> (toAdd: Set<URL>, toDelete: Set<URL>) {
    let s = Set(source)
    let t = Set(target)
    return (toAdd: s.subtracting(t), toDelete: t.subtracting(s))
}


func reconcileLists(db: Database, source: [URL], target: [URL]) -> EventLoopFuture<Void> {
    let (toAdd, toDelete) = diff(source: source, target: target)
    let insertions = db.withConnection { db in
        toAdd.map { Package(url: $0) }
            .map { $0.create(on: db) }
            .flatten(on: db.eventLoop)
    }
    let deletions: EventLoopFuture<Void> = db.withConnection { db in
        toDelete
            .map { url in
                Package.query(on: db)
                    .filter(by: url)
                    .first()
                    .unwrap(or: Abort(.notFound))
                    .flatMap { pkg in
                        pkg.delete(on: db)
                }
        }
        .flatten(on: db.eventLoop)
    }
    return insertions.and(deletions).transform(to: ())
}
