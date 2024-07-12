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


struct AppEnvironment: Sendable {
    var allowBuildTriggers: @Sendable () -> Bool
    var allowTwitterPosts: @Sendable () -> Bool
    var apiSigningKey: @Sendable () -> String?
    var appVersion: @Sendable () -> String?
    var awsAccessKeyId: @Sendable () -> String?
    var awsDocsBucket: @Sendable () -> String?
    var awsReadmeBucket: @Sendable () -> String?
    var awsSecretAccessKey: @Sendable () -> String?
    var buildTimeout: @Sendable () -> Int
    var builderToken: @Sendable () -> String?
    var buildTriggerAllowList: @Sendable () -> [Package.Id]
    var buildTriggerDownscaling: @Sendable () -> Double
    var buildTriggerLatestSwiftVersionDownscaling: @Sendable () -> Double
    var collectionSigningCertificateChain: @Sendable () -> [URL]
    var collectionSigningPrivateKey: @Sendable () -> Data?
    var currentReferenceCache: @Sendable () -> CurrentReferenceCache?
    var date: @Sendable () -> Date
    var dbId: @Sendable () -> String?
    var environment: @Sendable () -> Environment
    var fetchDocumentation: @Sendable (_ client: Client, _ url: URI) async throws -> ClientResponse
    var fetchHTTPStatusCode: @Sendable (_ url: String) async throws -> HTTPStatus
    var fetchPackageList: @Sendable (_ client: Client) async throws -> [URL]
    var fetchPackageDenyList: @Sendable (_ client: Client) async throws -> [URL]
    var fetchLicense: @Sendable (_ client: Client, _ owner: String, _ repository: String) async -> Github.License?
    var fetchMetadata: @Sendable (_ client: Client, _ owner: String, _ repository: String) async throws -> Github.Metadata
    var fetchReadme: @Sendable (_ client: Client, _ owner: String, _ repository: String) async -> Github.Readme?
    var fetchS3Readme: @Sendable (_ client: Client, _ owner: String, _ repository: String) async throws -> String
    var fileManager: FileManager
    var getStatusCount: @Sendable (_ client: Client,
                                   _ status: Gitlab.Builder.Status) -> EventLoopFuture<Int>
    var git: Git
    var githubToken: @Sendable () -> String?
    var gitlabApiToken: @Sendable () -> String?
    var gitlabPipelineToken: @Sendable () -> String?
    var gitlabPipelineLimit: @Sendable () -> Int
    var hideStagingBanner: @Sendable () -> Bool
    var httpClient: @Sendable () -> Client
    var loadSPIManifest: @Sendable (String) -> SPIManifest.Manifest?
    var logger: @Sendable () -> Logger
    var mastodonCredentials: @Sendable () -> Mastodon.Credentials?
    var mastodonPost: @Sendable (_ client: Client, _ post: String) async throws -> Void
    var metricsPushGatewayUrl: @Sendable () -> String?
    var plausibleBackendReportingSiteID: @Sendable () -> String?
    var postPlausibleEvent: @Sendable (Client, Plausible.Event.Kind, Plausible.Path, User?) async throws -> Void
    var random: @Sendable (_ range: ClosedRange<Double>) -> Double
    var runnerIds: @Sendable () -> [String]
    var setHTTPClient: @Sendable (Client) -> Void
    var setLogger: @Sendable (Logger) -> Void
    var shell: Shell
    var siteURL: @Sendable () -> String
    var storeS3Readme: @Sendable (_ owner: String,
                                  _ repository: String,
                                  _ readme: String) async throws -> String
    var storeS3ReadmeImages: @Sendable (_ client: Client,
                                        _ imagesToCache: [Github.Readme.ImageToCache]) async throws -> Void
    var timeZone: @Sendable () -> TimeZone
    var triggerBuild: @Sendable (_ client: Client,
                                 _ buildId: Build.Id,
                                 _ cloneURL: String,
                                 _ isDocBuild: Bool,
                                 _ platform: Build.Platform,
                                 _ reference: Reference,
                                 _ swiftVersion: SwiftVersion,
                                 _ versionID: Version.Id) -> EventLoopFuture<Build.TriggerResponse>
}


extension AppEnvironment {
    var buildTriggerCandidatesWithLatestSwiftVersion: Bool {
        guard buildTriggerLatestSwiftVersionDownscaling() < 1 else { return true }
        return random(0...1) < Current.buildTriggerLatestSwiftVersionDownscaling()
    }

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
    nonisolated(unsafe) static var httpClient: Client!
    nonisolated(unsafe) static var logger: Logger!

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
        apiSigningKey: { Environment.get("API_SIGNING_KEY") },
        appVersion: { App.appVersion },
        awsAccessKeyId: { Environment.get("AWS_ACCESS_KEY_ID") },
        awsDocsBucket: { Environment.get("AWS_DOCS_BUCKET") },
        awsReadmeBucket: { Environment.get("AWS_README_BUCKET") },
        awsSecretAccessKey: { Environment.get("AWS_SECRET_ACCESS_KEY") },
        buildTimeout: { Environment.get("BUILD_TIMEOUT").flatMap(Int.init) ?? 10 },
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
        currentReferenceCache: { .live },
        date: { .init() },
        dbId: { Environment.get("DATABASE_ID") },
        environment: { (try? Environment.detect()) ?? .development },
        fetchDocumentation: { client, url in try await client.get(url) },
        fetchHTTPStatusCode: { url in try await Networking.fetchHTTPStatusCode(url) },
        fetchPackageList: { client in try await liveFetchPackageList(client) },
        fetchPackageDenyList: { client in try await liveFetchPackageDenyList(client) },
        fetchLicense: { client, owner, repo in await Github.fetchLicense(client:client, owner: owner, repository: repo) },
        fetchMetadata: { client, owner, repo in try await Github.fetchMetadata(client:client, owner: owner, repository: repo) },
        fetchReadme: { client, owner, repo in await Github.fetchReadme(client:client, owner: owner, repository: repo) },
        fetchS3Readme: { client, owner, repo in try await S3Store.fetchReadme(client:client, owner: owner, repository: repo) },
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
        mastodonPost: { client, message in try await Mastodon.post(client: client, message: message) },
        metricsPushGatewayUrl: { Environment.get("METRICS_PUSHGATEWAY_URL") },
        plausibleBackendReportingSiteID: { Environment.get("PLAUSIBLE_BACKEND_REPORTING_SITE_ID") },
        postPlausibleEvent: { client, kind, path, user in try await Plausible.postEvent(client: client, kind: kind, path: path, user: user) },
        random: { range in Double.random(in: range) },
        runnerIds: {
            Environment.get("RUNNER_IDS")
                .map { Data($0.utf8) }
                .flatMap { try? JSONDecoder().decode([String].self, from: $0) }
            ?? []
        },
        setHTTPClient: { client in Self.httpClient = client },
        setLogger: { logger in Self.logger = logger },
        shell: .live,
        siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" },
        storeS3Readme: { owner, repo, readme in try await S3Store.storeReadme(owner: owner, repository: repo, readme: readme) },
        storeS3ReadmeImages: { client, images in try await S3Store.storeReadmeImages(client: client, imagesToCache: images) },
        timeZone: { .current },
        triggerBuild: { client, buildId, cloneURL, isDocBuild, platform, ref, swiftVersion, versionID in
            Gitlab.Builder.triggerBuild(client: client,
                                        buildId: buildId,
                                        cloneURL: cloneURL,
                                        isDocBuild: isDocBuild,
                                        platform: platform,
                                        reference: ref,
                                        swiftVersion: swiftVersion,
                                        versionID: versionID)
        }
    )
}


private enum Networking {
    static func fetchHTTPStatusCode(_ url: String) async throws -> HTTPStatus {
        var config = HTTPClient.Configuration()
        // We're forcing HTTP/1 due to a bug in Github's HEAD request handling
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1676
        config.httpVersion = .http1Only
        let client = HTTPClient(eventLoopGroupProvider: .singleton, configuration: config)
        return try await run {
            var req = HTTPClientRequest(url: url)
            req.method = .HEAD
            return try await client.execute(req, timeout: .seconds(2)).status
        } defer: {
            try await client.shutdown()
        }
    }
}


struct FileManager: Sendable {
    var attributesOfItem: @Sendable (_ path: String) throws -> [FileAttributeKey : Any]
    var contentsOfDirectory: @Sendable (_ path: String) throws -> [String]
    var contents: @Sendable (_ atPath: String) -> Data?
    var checkoutsDirectory: @Sendable () -> String
    var createDirectory: @Sendable (String, Bool, [FileAttributeKey : Any]?) throws -> Void
    var fileExists: @Sendable (String) -> Bool
    var removeItem: @Sendable (_ path: String) throws -> Void
    var workingDirectory: @Sendable () -> String

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
    func fileExists(atPath path: String) -> Bool { fileExists(path) }
    func removeItem(atPath path: String) throws { try removeItem(path) }

    static let live: Self = .init(
        attributesOfItem: { try Foundation.FileManager.default.attributesOfItem(atPath: $0) },
        contentsOfDirectory: { try Foundation.FileManager.default.contentsOfDirectory(atPath: $0) },
        contents: { Foundation.FileManager.default.contents(atPath: $0) },
        checkoutsDirectory: { Environment.get("CHECKOUTS_DIR") ?? DirectoryConfiguration.detect().workingDirectory + "SPI-checkouts" },
        createDirectory: { try Foundation.FileManager.default.createDirectory(atPath: $0, withIntermediateDirectories: $1, attributes: $2) },
        fileExists: { Foundation.FileManager.default.fileExists(atPath: $0) },
        removeItem: { try Foundation.FileManager.default.removeItem(atPath: $0) },
        workingDirectory: { DirectoryConfiguration.detect().workingDirectory }
    )
}


extension FileManager {
    func cacheDirectoryPath(for package: Package) -> String? {
        guard let dirname = package.cacheDirectoryName else { return nil }
        return checkoutsDirectory() + "/" + dirname
    }
}


struct Git: Sendable {
    var commitCount: @Sendable (String) async throws -> Int
    var firstCommitDate: @Sendable (String) async throws -> Date
    var lastCommitDate: @Sendable (String) async throws -> Date
    var getTags: @Sendable (String) async throws -> [Reference]
    var hasBranch: @Sendable (Reference, String) async throws -> Bool
    var revisionInfo: @Sendable (Reference, String) async throws -> RevisionInfo
    var shortlog: @Sendable (String) async throws -> String

    static let live: Self = .init(
        commitCount: { path in try await commitCount(at: path) },
        firstCommitDate: { path in try await firstCommitDate(at: path) },
        lastCommitDate: { path in try await lastCommitDate(at: path) },
        getTags: { path in try await getTags(at: path) },
        hasBranch: { ref, path in try await hasBranch(ref, at: path) },
        revisionInfo: { ref, path in try await revisionInfo(ref, at: path) },
        shortlog: { path in try await shortlog(at: path) }
    )
}


struct Shell: Sendable {
    var run: @Sendable (ShellOutCommand, String) async throws -> String

    // also provide pass-through methods to preserve argument labels
    @discardableResult
    func run(command: ShellOutCommand, at path: String = ".") async throws -> String {
        do {
            return try await run(command, path)
        } catch {
            // re-package error to capture more information
            throw AppError.shellCommandFailed(command.description, path, error.localizedDescription)
        }
    }

    static let live: Self = .init(
        run: {
            let res = try await ShellOut.shellOut(to: $0, at: $1, logger: Current.logger())
            if !res.stderr.isEmpty {
                Current.logger().warning("stderr: \(res.stderr)")
            }
            return res.stdout
        }
    )
}


#if DEBUG
nonisolated(unsafe) var Current: AppEnvironment = .live
#else
let Current: AppEnvironment = .live
#endif
