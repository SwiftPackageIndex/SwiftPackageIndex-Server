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

import Dependencies
import DependenciesMacros
import Vapor


@DependencyClient
struct EnvironmentClient {
    // See https://swiftpackageindex.com/pointfreeco/swift-dependencies/main/documentation/dependenciesmacros/dependencyclient()#Restrictions
    // regarding the use of XCTFail here.
    // Closures that are throwing or return Void don't need this, because they automatically get the default failing
    // mechanism when they're not set up in a test.
    var allowBuildTriggers: @Sendable () -> Bool = { XCTFail("allowBuildTriggers"); return true }
    var allowSocialPosts: @Sendable () -> Bool = { XCTFail("allowSocialPosts"); return true }
    var apiSigningKey: @Sendable () -> String?
    var appVersion: @Sendable () -> String?
    var awsAccessKeyId: @Sendable () -> String?
    var awsDocsBucket: @Sendable () -> String?
    var awsReadmeBucket: @Sendable () -> String?
    var awsSecretAccessKey: @Sendable () -> String?
    var builderToken: @Sendable () -> String?
    var buildTimeout: @Sendable () -> Int = { XCTFail("buildTimeout"); return 10 }
    var buildTriggerAllowList: @Sendable () -> [Package.Id] = { XCTFail("buildTriggerAllowList"); return [] }
    var buildTriggerDownscaling: @Sendable () -> Double = { XCTFail("buildTriggerDownscaling"); return 1 }
    var buildTriggerLatestSwiftVersionDownscaling: @Sendable () -> Double = { XCTFail("buildTriggerLatestSwiftVersionDownscaling"); return 1 }
    var collectionSigningCertificateChain: @Sendable () -> [URL] = { XCTFail("collectionSigningCertificateChain"); return [] }
    var collectionSigningPrivateKey: @Sendable () -> Data?
    var current: @Sendable () -> Environment = { XCTFail("current"); return .development }
    var currentReferenceCache: @Sendable () -> CurrentReferenceCache?
    var dbId: @Sendable () -> String?
    var mastodonCredentials: @Sendable () -> Mastodon.Credentials?
    var mastodonPost: @Sendable (_ client: Client, _ post: String) async throws -> Void
    var random: @Sendable (_ range: ClosedRange<Double>) -> Double = { XCTFail("random"); return Double.random(in: $0) }

    enum FailureMode: String {
        case fetchMetadataFailed
        case findOrCreateRepositoryFailed
        case invalidURL
        case noRepositoryMetadata
        case repositorySaveFailed
        case repositorySaveUniqueViolation
    }
    var shouldFail: @Sendable (_ failureMode: FailureMode) -> Bool = { _ in false }
}


extension EnvironmentClient: DependencyKey {
    static var liveValue: EnvironmentClient {
        .init(
            allowBuildTriggers: {
                Environment.get("ALLOW_BUILD_TRIGGERS").flatMap(\.asBool) ?? Constants.defaultAllowBuildTriggering
            },
            allowSocialPosts: {
                Environment.get("ALLOW_SOCIAL_POSTS")
                    .flatMap(\.asBool)
                    ?? Constants.defaultAllowSocialPosts
            },
            apiSigningKey: { Environment.get("API_SIGNING_KEY") },
            appVersion: { App.appVersion },
            awsAccessKeyId: { Environment.get("AWS_ACCESS_KEY_ID") },
            awsDocsBucket: { Environment.get("AWS_DOCS_BUCKET") },
            awsReadmeBucket: { Environment.get("AWS_README_BUCKET") },
            awsSecretAccessKey: { Environment.get("AWS_SECRET_ACCESS_KEY") },
            builderToken: { Environment.get("BUILDER_TOKEN") },
            buildTimeout: { Environment.get("BUILD_TIMEOUT").flatMap(Int.init) ?? 10 },
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
                    "package_collections.cer",
                    "AppleWWDRCAG3.cer",
                    "AppleIncRootCertificate.cer",
                ].map { SignedCollection.certsDir.appendingPathComponent($0) }
            },
            collectionSigningPrivateKey: {
                Environment.get("COLLECTION_SIGNING_PRIVATE_KEY").map { Data($0.utf8) }
            },
            current: { (try? Environment.detect()) ?? .development },
            currentReferenceCache: { .live },
            dbId: { Environment.get("DATABASE_ID") },
            mastodonCredentials: {
                Environment.get("MASTODON_ACCESS_TOKEN")
                    .map(Mastodon.Credentials.init(accessToken:))
            },
            mastodonPost: { client, message in try await Mastodon.post(client: client, message: message) },
            random: { range in Double.random(in: range) },
            shouldFail: { failureMode in
                let shouldFail = Environment.get("FAILURE_MODE")
                    .map { Data($0.utf8) }
                    .flatMap { try? JSONDecoder().decode([String: Double].self, from: $0) } ?? [:]
                guard let rate = shouldFail[failureMode.rawValue] else { return false }
                return Double.random(in: 0...1) <= rate
            }
        )
    }
}


extension EnvironmentClient {
    var buildTriggerCandidatesWithLatestSwiftVersion: Bool {
        guard buildTriggerLatestSwiftVersionDownscaling() < 1 else { return true }
        return random(0...1) < buildTriggerLatestSwiftVersionDownscaling()
    }

    var buildTriggerDownscalingAccepted: Bool {
        random(0...1) < buildTriggerDownscaling()
    }
}


extension EnvironmentClient: TestDependencyKey {
    static var testValue: Self {
        // sas 2024-11-22:
        // For a few attributes we provide a default value overriding the XCTFail, because theis use is too
        // pervasive and would require the vast majority of tests to be wrapped with `withDependencies`.
        // We can do so at a later time once more tests are transitioned over for other dependencies. This is
        // the exact same default behaviour we had with the Current dependency injection. It did not have
        // a "fail if not set" mechanism and relied on default values only. We're simply preserving this
        // mechanism for a few heavily used dependencies at the moment.
        var mock = Self()
        mock.appVersion = { "test" }
        mock.current = { .development }
        return mock
    }
}


extension DependencyValues {
    var environment: EnvironmentClient {
        get { self[EnvironmentClient.self] }
        set { self[EnvironmentClient.self] = newValue }
    }
}
