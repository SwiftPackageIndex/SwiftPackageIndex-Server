import Fluent
import Vapor
import _NIOConcurrency


struct ReconcileCommand: Command {
    struct Signature: CommandSignature { }

    var help: String { "Reconcile package list with server" }

    func run(using context: CommandContext, signature: Signature) throws {
        let promise = context.application.eventLoopGroup.next()
            .makePromise(of: Void.self)
        promise.completeWithAsync {
            let logger = Logger(component: "reconcile")
            logger.info("Reconciling ...")
            try await reconcile(client: context.application.client,
                                 database: context.application.db)
            logger.info("done.")
        }
        try promise.futureResult.wait()
    }
}


func reconcile(client: Client, database: Database) async throws {
    async let packageList = try Current.fetchPackageList(client)
    async let currentList = try fetchCurrentPackageList(database)
    return try await reconcileLists(db: database,
                                    source: packageList,
                                    target: currentList)
}


func liveFetchPackageList(_ client: Client) async throws -> [URL] {
   try await client
        .get(Constants.packageListUri)
        .content
        .decode([String].self, using: JSONDecoder())
        .compactMap(URL.init(string:))
}


func fetchCurrentPackageList(_ db: Database) async throws -> [URL] {
    try await Package.query(on: db)
        .all()
        .map(\.url)
        .compactMap(URL.init(string:))
}


func diff(source: [URL], target: [URL]) -> (toAdd: Set<URL>, toDelete: Set<URL>) {
    let s = Set(source)
    let t = Set(target)
    return (toAdd: s.subtracting(t), toDelete: t.subtracting(s))
}


func reconcileLists(db: Database, source: [URL], target: [URL]) async throws {
    let (toAdd, toDelete) = diff(source: source, target: target)
    let insert = toAdd.map { Package(url: $0, processingStage: .reconciliation) }
    try await insert.create(on: db)
    for url in toDelete {
        try await Package.query(on: db)
            .filter(by: url)
            .delete()
    }
}
