import Vapor


struct AppEnvironment {
    var fetchMasterPackageList: (_ client: Client) throws -> EventLoopFuture<[URL]>
    var fetchMetadata: (_ client: Client, _ package: Package) throws -> EventLoopFuture<Github.Metadata>
    var githubToken: () -> String?
}

extension AppEnvironment {
    static let live: Self = .init(
        fetchMasterPackageList: liveFetchMasterPackageList,
        fetchMetadata: Github.fetchMetadata(client:package:),
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] }
    )
}


#if DEBUG
var Current: AppEnvironment = .live
#else
let Current: AppEnvironment = .live
#endif
