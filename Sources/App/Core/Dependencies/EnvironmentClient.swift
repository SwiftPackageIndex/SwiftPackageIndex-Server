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
    var allowBuildTriggers: @Sendable () -> Bool = { XCTFail(#function); return true }
    var allowSocialPosts: @Sendable () -> Bool = { XCTFail(#function); return true }
    var awsAccessKeyId: @Sendable () -> String?
    var awsDocsBucket: @Sendable () -> String?
    var awsReadmeBucket: @Sendable () -> String?
    var awsSecretAccessKey: @Sendable () -> String?
    var builderToken: @Sendable () -> String?
    var buildTimeout: @Sendable () -> Int = { XCTFail(#function); return 10 }
    var buildTriggerAllowList: @Sendable () -> [Package.Id] = { XCTFail(#function); return [] }
    var buildTriggerDownscaling: @Sendable () -> Double = { XCTFail(#function); return 1 }
    var buildTriggerLatestSwiftVersionDownscaling: @Sendable () -> Double = { XCTFail(#function); return 1 }
    // We're not defaulting current to XCTFail, because its use is too pervasive and would require the vast
    // majority of tests to be wrapped with `withDependencies`.
    // We can do so at a later time once more tests are transitioned over for other dependencies. This is
    // the exact same default behaviour we have with the Current dependency injection: it defaults to
    // .development and does not raise an error when not injected.
    var current: @Sendable () -> Environment = { .development }
    var mastodonCredentials: @Sendable () -> Mastodon.Credentials?
    var mastodonPost: @Sendable (_ client: Client, _ post: String) async throws -> Void
    var random: @Sendable (_ range: ClosedRange<Double>) -> Double = { XCTFail(#function); return Double.random(in: $0) }
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
            current: { (try? Environment.detect()) ?? .development },
            mastodonCredentials: {
                Environment.get("MASTODON_ACCESS_TOKEN")
                    .map(Mastodon.Credentials.init(accessToken:))
            },
            mastodonPost: { client, message in try await Mastodon.post(client: client, message: message) },
            random: { range in Double.random(in: range) }
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
    static var testValue: Self { Self() }
}


extension DependencyValues {
    var environment: EnvironmentClient {
        get { self[EnvironmentClient.self] }
        set { self[EnvironmentClient.self] = newValue }
    }
}
