import ShellOut
import Vapor


struct AppEnvironment {
    var allowBuildTriggers: () -> Bool
    var builderToken: () -> String?
    var buildTriggerDownscaling: () -> Double
    var date: () -> Date
    var fetchPackageList: (_ client: Client) throws -> EventLoopFuture<[URL]>
    var fetchLicense: (_ client: Client, _ package: Package) -> EventLoopFuture<Github.License?>
    var fetchMetadata: (_ client: Client, _ package: Package) -> EventLoopFuture<Github.Metadata>
    var fetchReadme: (_ client: Client, _ package: Package) -> EventLoopFuture<Github.Readme?>
    var fileManager: FileManager
    var getStatusCount: (_ client: Client,
                         _ status: Gitlab.Builder.Status) -> EventLoopFuture<Int>
    var githubToken: () -> String?
    var gitlabApiToken: () -> String?
    var gitlabPipelineToken: () -> String?
    var gitlabPipelineLimit: () -> Int
    var hideStagingBanner: () -> Bool
    var metricsPushGatewayUrl: () -> String?
    var random: (_ range: ClosedRange<Double>) -> Double
    var reportError: (_ client: Client, _ level: AppError.Level, _ error: Error) -> EventLoopFuture<Void>
    var rollbarToken: () -> String?
    var rollbarLogLevel: () -> AppError.Level
    var shell: Shell
    var siteURL: () -> String
    var twitterCredentials: () -> Twitter.Credentials?
    var twitterPostTweet: (_ client: Client, _ tweet: String) -> EventLoopFuture<Void>
}

extension AppEnvironment {
    static let live = AppEnvironment(
        allowBuildTriggers: {
            Environment.get("ALLOW_BUILD_TRIGGERS")
                .flatMap(\.asBool)
                ?? Constants.defaultAllowBuildTriggering
        },
        builderToken: { Environment.get("BUILDER_TOKEN") },
        buildTriggerDownscaling: {
            Environment.get("BUILD_TRIGGER_DOWNSCALING")
                .flatMap(Double.init)
                ?? 1.0
        },
        date: Date.init,
        fetchPackageList: liveFetchPackageList,
        fetchLicense: Github.fetchLicense(client:package:),
        fetchMetadata: Github.fetchMetadata(client:package:),
        fetchReadme: Github.fetchReadme(client:package:),
        fileManager: .live,
        getStatusCount: { client, status in
            Gitlab.Builder.getStatusCount(
                client: client,
                status: status,
                page: 1,
                pageSize: 100,
                maxPageCount: 5)
        },
        githubToken: { Environment.get("GITHUB_TOKEN") },
        gitlabApiToken: { Environment.get("GITLAB_API_TOKEN") },
        gitlabPipelineToken: { Environment.get("GITLAB_PIPELINE_TOKEN") },
        gitlabPipelineLimit: {
            Environment.get("GITLAB_PIPELINE_LIMIT").flatMap(Int.init)
            ?? Constants.defaultGitlabPipelineLimit
        },
        hideStagingBanner: {
            Environment.get("HIDE_STAGING_BANNER").flatMap(\.asBool)
                ?? Constants.defaultHideStagingBanner
        },
        metricsPushGatewayUrl: { Environment.get("METRICS_PUSHGATEWAY_URL") },
        random: Double.random,
        reportError: AppError.report,
        rollbarToken: { Environment.get("ROLLBAR_TOKEN") },
        rollbarLogLevel: {
            Environment
                .get("ROLLBAR_LOG_LEVEL")
                .flatMap(AppError.Level.init(rawValue:)) ?? .critical },
        shell: .live,
        siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" },
        twitterCredentials: {
            guard let consumerKey = Environment.get("TWITTER_CONSUMER_KEY"),
                  let consumerSecret = Environment.get("TWITTER_CONSUMER_SECRET"),
                  let userKey = Environment.get("TWITTER_USER_KEY"),
                  let userSecret = Environment.get("TWITTER_USER_SECRET")
            else { return nil }
            return .init(consumer: (key: consumerKey, secret: consumerSecret),
                         user: (key: userKey, secret: userSecret))
        },
        twitterPostTweet: Twitter.post(client:tweet:)
    )
}


struct FileManager {
    var checkoutsDirectory: () -> String
    var createDirectory: (String, Bool, [FileAttributeKey : Any]?) throws -> Void
    var fileExists: (String) -> Bool
    var workingDirectory: () -> String
    // also provide pass-through methods to preserve argument labels
    func createDirectory(atPath path: String,
                         withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey : Any]?) throws {
        try createDirectory(path, createIntermediates, attributes)
    }
    func fileExists(atPath path: String) -> Bool { fileExists(path) }
    
    static let live: Self = .init(
        checkoutsDirectory: { Environment.get("CHECKOUTS_DIR") ?? DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts" },
        createDirectory: Foundation.FileManager.default.createDirectory(atPath:withIntermediateDirectories:attributes:),
        fileExists: Foundation.FileManager.default.fileExists(atPath:),
        workingDirectory: { DirectoryConfiguration.detect().workingDirectory }
    )
}


extension FileManager {
    func cacheDirectoryPath(for package: Package) -> String? {
        guard let dirname = package.cacheDirectoryName else { return nil }
        return checkoutsDirectory() + "/" + dirname
    }
}


struct Shell {
    var run: (ShellOutCommand, String) throws -> String
    // also provide pass-through methods to preserve argument labels
    @discardableResult
    func run(command: ShellOutCommand, at path: String = ".") throws -> String {
        do {
            return try run(command, path)
        } catch {
            // re-package error to capture more information
            throw AppError.shellCommandFailed(command.string, path, error.localizedDescription)
        }
    }
    
    static let live: Self = .init(run: { cmd, path in
        try ShellOut.shellOut(to: cmd, at: path)
    })
}


#if DEBUG
var Current: AppEnvironment = .live
#else
let Current: AppEnvironment = .live
#endif
