// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import AsyncHTTPClient
import S3Store
import SPIManifest
import ShellOut
import Vapor
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


struct AppEnvironment {
    var allowBuildTriggers: () -> Bool
    var allowTwitterPosts: () -> Bool
    var apiTokens: () -> Set<String>
    var appVersion: () -> String?
    var awsAccessKeyId: () -> String?
    var awsDocsBucket: () -> String?
    var awsReadmeBucket: () -> String?
    var awsSecretAccessKey: () -> String?
    var builderToken: () -> String?
    var buildTriggerAllowList: () -> [Package.Id]
    var buildTriggerDownscaling: () -> Double
    var buildTriggerLatestSwiftVersionDownscaling: () -> Double
    var collectionSigningCertificateChain: () -> [URL]
    var collectionSigningPrivateKey: () -> Data?
    var date: () -> Date
    var dbId: () -> String?
    var fetchDocumentation: (_ client: Client, _ url: URI) async throws -> ClientResponse
    var fetchHTTPStatusCode: (_ url: String) async throws -> HTTPStatus
    var fetchPackageList: (_ client: Client) async throws -> [URL]
    var fetchLicense: (_ client: Client, _ packageUrl: String) async -> Github.License?
    var fetchMetadata: (_ client: Client, _ packageUrl: String) async throws -> Github.Metadata
    var fetchReadme: (_ client: Client, _ packageUrl: String) async -> Github.Readme?
    var fetchS3Readme: (_ client: Client, _ owner: String, _ repository: String) async throws -> String
    var fileManager: FileManager
    var getStatusCount: (_ client: Client,
                         _ status: Gitlab.Builder.Status) -> EventLoopFuture<Int>
    var git: Git
    var githubToken: () -> String?
    var gitlabApiToken: () -> String?
    var gitlabPipelineToken: () -> String?
    var gitlabPipelineLimit: () -> Int
    var hideStagingBanner: () -> Bool
    var httpClient: () -> Client
    var loadSPIManifest: (String) -> SPIManifest.Manifest?
    var logger: () -> Logger
    var mastodonCredentials: () -> Mastodon.Credentials?
    var mastodonPost: (_ client: Client, _ post: String) async throws -> Void
    var metricsPushGatewayUrl: () -> String?
    var plausibleBackendReportingSiteID: () -> String?
    var postPlausibleEvent: (Client, Plausible.Event.Kind, Plausible.Path, User?) async throws -> Void
    var random: (_ range: ClosedRange<Double>) -> Double
    var setHTTPClient: (Client) -> Void
    var setLogger: (Logger) -> Void
    var shell: Shell
    var siteURL: () -> String
    var storeS3Readme: (_ owner: String, _ repository: String, _ readme: String) async throws -> String
    var triggerBuild: (_ client: Client,
                       _ logger: Logger,
                       _ buildId: Build.Id,
                       _ cloneURL: String,
                       _ platform: Build.Platform,
                       _ reference: Reference,
                       _ swiftVersion: SwiftVersion,
                       _ versionID: Version.Id) -> EventLoopFuture<Build.TriggerResponse>
    var twitterCredentials: () -> Twitter.Credentials?
    var twitterPost: (_ client: Client, _ tweet: String) async throws -> Void
}


extension AppEnvironment {
    var buildTriggerCandidatesWithLatestSwiftVersion: Bool {
        guard buildTriggerLatestSwiftVersionDownscaling() < 1 else { return true }
        return random(0...1) < Current.buildTriggerLatestSwiftVersionDownscaling()
    }

    func isValidAPIToken(_ token: String) -> Bool { apiTokens().contains(token) }

    func postPlausibleEvent(_ event: Plausible.Event.Kind, path: Plausible.Path, user: User?) {
        Task {
            do {
                try await Current.postPlausibleEvent(Current.httpClient(), event, path, user)
            } catch {
                Current.logger().warning("Plausible.postEvent failed: \(error)")
            }
        }
    }
}


extension AppEnvironment {
    static let _apiTokens = {
        Environment.get("API_TOKENS")
            .map { Data($0.utf8) }
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) }
            .map { Set($0) } ?? .init()
    }()
    static var httpClient: Client!
    static var logger: Logger!

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
        apiTokens: { _apiTokens },
        appVersion: { App.appVersion },
        awsAccessKeyId: { Environment.get("AWS_ACCESS_KEY_ID") },
        awsDocsBucket: { Environment.get("AWS_DOCS_BUCKET") },
        awsReadmeBucket: { Environment.get("AWS_README_BUCKET") },
        awsSecretAccessKey: { Environment.get("AWS_SECRET_ACCESS_KEY") },
        builderToken: { Environment.get("BUILDER_TOKEN") },
        buildTriggerAllowList: {
            Environment.get("BUILD_TRIGGER_ALLOW_LIST")
                .map { Data($0.utf8) }
                .flatMap { try? JSONDecoder().decode([Package.Id].self, from: $0) }
            ?? []
        },
        buildTriggerDownscaling: {
            Environment.get("BUILD_TRIGGER_DOWNSCALING")
                .flatMap(Double.init)
                ?? 1.0
        },
        buildTriggerLatestSwiftVersionDownscaling: {
            Environment.get("BUILD_TRIGGER_LATEST_SWIFT_VERSION_DOWNSCALING")
                .flatMap(Double.init)
                ?? 1.0
        },
        collectionSigningCertificateChain: {
            [
                SignedCollection.certsDir
                    .appendingPathComponent("package_collections.cer"),
                SignedCollection.certsDir
                    .appendingPathComponent("AppleWWDRCAG3.cer"),
                SignedCollection.certsDir
                    .appendingPathComponent("AppleIncRootCertificate.cer")
            ]
        },
        collectionSigningPrivateKey: {
            Environment.get("COLLECTION_SIGNING_PRIVATE_KEY")
                .map { Data($0.utf8) }
        },
        date: Date.init,
        dbId: { Environment.get("DATABASE_ID") },
        fetchDocumentation: { client, url in try await client.get(url) },
        fetchHTTPStatusCode: Networking.fetchHTTPStatusCode,
        fetchPackageList: liveFetchPackageList,
        fetchLicense: Github.fetchLicense(client:packageUrl:),
        fetchMetadata: Github.fetchMetadata(client:packageUrl:),
        fetchReadme: Github.fetchReadme(client:packageUrl:),
        fetchS3Readme: S3Store.fetchReadme(client:owner:repository:),
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
        httpClient: { httpClient },
        loadSPIManifest: { path in SPIManifest.Manifest.load(in: path) },
        logger: { logger },
        mastodonCredentials: {
            Environment.get("MASTODON_ACCESS_TOKEN")
                .map(Mastodon.Credentials.init(accessToken:))
        },
        mastodonPost: Mastodon.post(client:message:),
        metricsPushGatewayUrl: { Environment.get("METRICS_PUSHGATEWAY_URL") },
        plausibleBackendReportingSiteID: { Environment.get("PLAUSIBLE_BACKEND_REPORTING_SITE_ID") },
        postPlausibleEvent: Plausible.postEvent,
        random: Double.random,
        setHTTPClient: { client in Self.httpClient = client },
        setLogger: { logger in Self.logger = logger },
        shell: .live,
        siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" },
        storeS3Readme: S3Store.storeReadme(owner:repository:readme:),
        triggerBuild: Gitlab.Builder.triggerBuild,
        twitterCredentials: {
            guard let apiKey = Environment.get("TWITTER_API_KEY"),
                  let apiKeySecret = Environment.get("TWITTER_API_SECRET"),
                  let accessToken = Environment.get("TWITTER_ACCESS_TOKEN_KEY"),
                  let accessTokenSecret = Environment.get("TWITTER_ACCESS_TOKEN_SECRET")
            else { return nil }
            return .init(apiKey: (key: apiKey, secret: apiKeySecret),
                         accessToken: (key: accessToken, secret: accessTokenSecret))
        },
        twitterPost: Twitter.post(client:tweet:)
    )
}


private enum Networking {
    static func fetchHTTPStatusCode(_ url: String) async throws -> HTTPStatus {
        var config = HTTPClient.Configuration()
        // We're forcing HTTP/1 due to a bug in Github's HEAD request handling
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1676
        config.httpVersion = .http1Only
        let client = HTTPClient(eventLoopGroupProvider: .createNew, configuration: config)
        defer { try? client.syncShutdown() }
        var req = HTTPClientRequest(url: url)
        req.method = .HEAD
        return try await client.execute(req, timeout: .seconds(2)).status
    }
}


struct FileManager {
    var attributesOfItem: (_ path: String) throws -> [FileAttributeKey : Any]
    var contentsOfDirectory: (_ path: String) throws -> [String]
    var contents: (_ atPath: String) -> Data?
    var checkoutsDirectory: () -> String
    var createDirectory: (String, Bool, [FileAttributeKey : Any]?) throws -> Void
    var createFile: (_ atPath: String, _ contents: Data?, _ attributes: [FileAttributeKey : Any]?) -> Bool
    var fileExists: (String) -> Bool
    var removeItem: (_ path: String) throws -> Void
    var withTempDir: ((String) async throws -> Void) async throws -> Void
    var workingDirectory: () -> String

    // pass-through methods to preserve argument labels
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        try attributesOfItem(path)
    }
    func contents(atPath path: String) -> Data? { contents(path) }
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try contentsOfDirectory(path)
    }
    func createDirectory(atPath path: String,
                         withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey : Any]?) throws {
        try createDirectory(path, createIntermediates, attributes)
    }
    func createFile(atPath path: String, contents: Data?, attributes: [FileAttributeKey : Any]? = nil) -> Bool {
        createFile(path, contents, attributes)
    }
    func fileExists(atPath path: String) -> Bool { fileExists(path) }
    func removeItem(atPath path: String) throws { try removeItem(path) }

    static let live: Self = .init(
        attributesOfItem: Foundation.FileManager.default.attributesOfItem(atPath:),
        contentsOfDirectory: Foundation.FileManager.default.contentsOfDirectory(atPath:),
        contents: Foundation.FileManager.default.contents(atPath:),
        checkoutsDirectory: { Environment.get("CHECKOUTS_DIR") ?? DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts" },
        createDirectory: Foundation.FileManager.default.createDirectory(atPath:withIntermediateDirectories: attributes:),
        createFile: Foundation.FileManager.default.createFile(atPath:contents:attributes:),
        fileExists: Foundation.FileManager.default.fileExists(atPath:),
        removeItem: Foundation.FileManager.default.removeItem(atPath:),
        withTempDir: { try await TempDir(body: $0) },
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
    var shortlog: (String) throws -> String

    static let live: Self = .init(
        commitCount: commitCount(at:),
        firstCommitDate: firstCommitDate(at:),
        lastCommitDate: lastCommitDate(at:),
        getTags: getTags(at:),
        showDate: showDate(_:at:),
        revisionInfo: revisionInfo(_:at:),
        shortlog: shortlog(at:)
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
