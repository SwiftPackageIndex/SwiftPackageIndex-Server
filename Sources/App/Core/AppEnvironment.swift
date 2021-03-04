import ShellOut
import Vapor


struct AppEnvironment {
    var allowBuildTriggers: () -> Bool
    var allowTwitterPosts: () -> Bool
    var appVersion: () -> String?
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
    var git: Git
    var githubToken: () -> String?
    var gitlabApiToken: () -> String?
    var gitlabPipelineToken: () -> String?
    var gitlabPipelineLimit: () -> Int
    var hideStagingBanner: () -> Bool
    var logger: () -> Logger?
    var metricsPushGatewayUrl: () -> String?
    var random: (_ range: ClosedRange<Double>) -> Double
    var reAnalyzeVersionsBeforeDate: () -> Date?
    var reportError: (_ client: Client, _ level: AppError.Level, _ error: Error) -> EventLoopFuture<Void>
    var rollbarToken: () -> String?
    var rollbarLogLevel: () -> AppError.Level
    var setLogger: (Logger) -> Void
    var shell: Shell
    var siteURL: () -> String
    var twitterCredentials: () -> Twitter.Credentials?
    var twitterPostTweet: (_ client: Client, _ tweet: String) -> EventLoopFuture<Void>
}

extension AppEnvironment {
    static var logger: Logger?

    static let live = AppEnvironment(
        allowBuildTriggers: {
            Environment.get("ALLOW_BUILD_TRIGGERS")
                .flatMap(\.asBool)
                ?? Constants.defaultAllowBuildTriggering
        },
        allowTwitterPosts: {
            Environment.get("ALLOW_TWITTER_POSTS")
                .flatMap(\.asBool)
                ?? Constants.defaultAllowTwitterPosts
        },
        appVersion: { App.appVersion },
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
        git: .live,
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
        logger: { logger },
        metricsPushGatewayUrl: { Environment.get("METRICS_PUSHGATEWAY_URL") },
        random: Double.random,
        reAnalyzeVersionsBeforeDate: { Environment.get("RE_ANALYZE_VERSIONS_BEFORE_DATE")
            .flatMap(Date.init(yyyyMMdd:))
        },
        reportError: AppError.report,
        rollbarToken: { Environment.get("ROLLBAR_TOKEN") },
        rollbarLogLevel: {
            Environment
                .get("ROLLBAR_LOG_LEVEL")
                .flatMap(AppError.Level.init(rawValue:)) ?? .critical },
        setLogger: { logger in Self.logger = logger },
        shell: .live,
        siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" },
        twitterCredentials: {
            guard let apiKey = Environment.get("TWITTER_API_KEY"),
                  let apiKeySecret = Environment.get("TWITTER_API_SECRET"),
                  let accessToken = Environment.get("TWITTER_ACCESS_TOKEN_KEY"),
                  let accessTokenSecret = Environment.get("TWITTER_ACCESS_TOKEN_SECRET")
            else { return nil }
            return .init(apiKey: (key: apiKey, secret: apiKeySecret),
                         accessToken: (key: accessToken, secret: accessTokenSecret))
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


struct Git {
    var commitCount: (String) throws -> Int
    var firstCommitDate: (String) throws -> Date
    var lastCommitDate: (String) throws -> Date
    var getTags: (String) throws -> [Reference]
    var showDate: (CommitHash, String) throws -> Date
    var revisionInfo: (Reference, String) throws -> RevisionInfo

    static let live: Self = .init(
        commitCount: commitCount(at:),
        firstCommitDate: firstCommitDate(at:),
        lastCommitDate: lastCommitDate(at:),
        getTags: getTags(at:),
        showDate: showDate(_:at:),
        revisionInfo: revisionInfo(_:at:)
    )
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
