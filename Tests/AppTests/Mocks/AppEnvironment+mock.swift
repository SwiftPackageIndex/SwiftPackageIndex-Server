// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

@testable import App

import NIO
import Vapor


extension AppEnvironment {
    static func mock(eventLoop: EventLoop) -> Self {
        .init(
            allowBuildTriggers: { true },
            allowTwitterPosts: { true },
            appVersion: { "test" },
            builderToken: { nil },
            buildTriggerDownscaling: { 1.0 },
            collectionSigningCertificateChain: {
                [
                    SignedCollection.certsDir
                        .appendingPathComponent("package_collections_dev.cer"),
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
            dbId: { "db-id" },
            fetchPackageList: { _ in
                ["https://github.com/finestructure/Gala",
                 "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"].asURLs
            },
            fetchLicense: { _, _ in eventLoop.future(.init(htmlUrl: "https://github.com/foo/bar/blob/main/LICENSE")) },
            fetchMetadata: { _, _ in eventLoop.future(.mock) },
            fetchReadme: { _, _ in eventLoop.future(
                .init(downloadUrl: "https://raw.githubusercontent.com/foo/bar/main/README.md",
                      htmlUrl: "https://github.com/foo/bar/blob/main/README.md")
            )},
            fileManager: .mock,
            getStatusCount: { _, _ in eventLoop.future(100) },
            git: .mock,
            githubToken: { nil },
            gitlabApiToken: { nil },
            gitlabPipelineToken: { nil },
            gitlabPipelineLimit: { Constants.defaultGitlabPipelineLimit },
            hideStagingBanner: { false },
            logger: { nil },
            metricsPushGatewayUrl: { "http://pushgateway:9091" },
            random: Double.random,
            reportError: { _, _, _ in eventLoop.future(()) },
            rollbarToken: { nil },
            rollbarLogLevel: { .critical },
            setLogger: { _ in },
            shell: .mock,
            siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" },
            triggerBuild: { _, _, _, _, _, _, _ in
                eventLoop.future(.init(status: .ok, webUrl: "http://web_url"))
            },
            twitterCredentials: { nil },
            twitterPostTweet: { _, _ in eventLoop.future() }
        )
    }
}
