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
    var fetchMetadata: @Sendable (_ client: Client, _ owner: String, _ repository: String) async throws(Github.Error) -> Github.Metadata
    var fetchReadme: @Sendable (_ client: Client, _ owner: String, _ repository: String) async -> Github.Readme?
    var fetchS3Readme: @Sendable (_ client: Client, _ owner: String, _ repository: String) async throws -> String
    var fileManager: FileManager
    var getStatusCount: @Sendable (_ client: Client, _ status: Gitlab.Builder.Status) async throws -> Int
    var git: Git
    var githubToken: @Sendable () -> String?
    var gitlabApiToken: @Sendable () -> String?
    var gitlabPipelineToken: @Sendable () -> String?
    var gitlabPipelineLimit: @Sendable () -> Int
    var hideStagingBanner: @Sendable () -> Bool
    var maintenanceMessage: @Sendable () -> String?
    var loadSPIManifest: @Sendable (String) -> SPIManifest.Manifest?
    var logger: @Sendable () -> Logger
    var metricsPushGatewayUrl: @Sendable () -> String?
    var plausibleBackendReportingSiteID: @Sendable () -> String?
    var processingBuildBacklog: @Sendable () -> Bool
    var runnerIds: @Sendable () -> [String]
    var setLogger: @Sendable (Logger) -> Void
    var shell: Shell
    var siteURL: @Sendable () -> String
    var storeS3Readme: @Sendable (_ owner: String,
                                  _ repository: String,
                                  _ readme: String) async throws(S3Readme.Error) -> String
    var storeS3ReadmeImages: @Sendable (_ client: Client,
                                        _ imagesToCache: [Github.Readme.ImageToCache]) async throws(S3Readme.Error) -> Void
    var timeZone: @Sendable () -> TimeZone
    var triggerBuild: @Sendable (_ client: Client,
                                 _ buildId: Build.Id,
                                 _ cloneURL: String,
                                 _ isDocBuild: Bool,
                                 _ platform: Build.Platform,
                                 _ reference: Reference,
                                 _ swiftVersion: SwiftVersion,
                                 _ versionID: Version.Id) async throws -> Build.TriggerResponse
}


extension AppEnvironment {
    nonisolated(unsafe) static var logger: Logger!

    static let live = AppEnvironment(
        fetchMetadata: { client, owner, repo throws(Github.Error) in try await Github.fetchMetadata(client:client, owner: owner, repository: repo) },
        fetchReadme: { client, owner, repo in await Github.fetchReadme(client:client, owner: owner, repository: repo) },
        fetchS3Readme: { client, owner, repo in try await S3Readme.fetchReadme(client:client, owner: owner, repository: repo) },
        fileManager: .live,
        getStatusCount: { client, status in
            try await Gitlab.Builder.getStatusCount(client: client,
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
        maintenanceMessage: {
            Environment.get("MAINTENANCE_MESSAGE").flatMap(\.trimmed)
        },
        loadSPIManifest: { path in SPIManifest.Manifest.load(in: path) },
        logger: { logger },
        metricsPushGatewayUrl: { Environment.get("METRICS_PUSHGATEWAY_URL") },
        plausibleBackendReportingSiteID: { Environment.get("PLAUSIBLE_BACKEND_REPORTING_SITE_ID") },
        processingBuildBacklog: {
            Environment.get("PROCESSING_BUILD_BACKLOG").flatMap(\.asBool) ?? false
        },
        runnerIds: {
            Environment.get("RUNNER_IDS")
                .map { Data($0.utf8) }
                .flatMap { try? JSONDecoder().decode([String].self, from: $0) }
            ?? []
        },
        setLogger: { logger in Self.logger = logger },
        shell: .live,
        siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" },
        storeS3Readme: { owner, repo, readme throws(S3Readme.Error) in
            try await S3Readme.storeReadme(owner: owner, repository: repo, readme: readme)
        },
        storeS3ReadmeImages: { client, images throws(S3Readme.Error) in
            try await S3Readme.storeReadmeImages(client: client, imagesToCache: images)
        },
        timeZone: { .current },
        triggerBuild: { client, buildId, cloneURL, isDocBuild, platform, ref, swiftVersion, versionID in
            try await Gitlab.Builder.triggerBuild(client: client,
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
