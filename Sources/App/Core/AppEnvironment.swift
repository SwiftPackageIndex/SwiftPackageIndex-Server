import Vapor


struct AppEnvironment {
    var fetchMasterPackageList: (_ client: Client) throws -> EventLoopFuture<[URL]>
    var fetchMetadata: (_ client: Client, _ package: Package) throws -> EventLoopFuture<Github.Metadata>
    var fileManager: () -> FileManager
    var githubToken: () -> String?
}

extension AppEnvironment {
    static let live: Self = .init(
        fetchMasterPackageList: liveFetchMasterPackageList,
        fetchMetadata: Github.fetchMetadata(client:package:),
        fileManager: { .live },
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] }
    )
}


struct FileManager {
    var fileExists: (String) -> Bool
    var createDirectory: (String, Bool, [FileAttributeKey : Any]?) throws -> Void

    func fileExists(atPath path: String) -> Bool { fileExists(path) }
    func createDirectory(atPath path: String,
                         withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey : Any]?) throws {
        try createDirectory(path, createIntermediates, attributes)
    }

    static let live: Self = .init(
        fileExists: Foundation.FileManager.default.fileExists(atPath:),
        createDirectory: Foundation.FileManager.default.createDirectory(atPath:withIntermediateDirectories:attributes:))
}


#if DEBUG
var Current: AppEnvironment = .live
#else
let Current: AppEnvironment = .live
#endif
