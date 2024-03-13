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

@testable import App

import AsyncHTTPClient
import NIO
import Vapor


extension AppEnvironment {
    static func mock(eventLoop: EventLoop) -> Self {
        .init(
            allowBuildTriggers: { true },
            allowTwitterPosts: { true },
            apiSigningKey: { nil },
            appVersion: { "test" },
            awsAccessKeyId: { nil },
            awsDocsBucket: { "awsDocsBucket" },
            awsReadmeBucket: { "awsReadmeBucket" },
            awsSecretAccessKey: { nil },
            buildTimeout: { 10 },
            builderToken: { nil },
            buildTriggerAllowList: { [] },
            buildTriggerDownscaling: { 1.0 },
            buildTriggerLatestSwiftVersionDownscaling: { 1.0 },
            collectionSigningCertificateChain: AppEnvironment.live.collectionSigningCertificateChain,
            collectionSigningPrivateKey: AppEnvironment.live.collectionSigningPrivateKey,
            date: Date.init,
            dbId: { "db-id" },
            environment: { .development },
            fetchDocumentation: { _, _ in .init(status: .ok) },
            fetchHTTPStatusCode: { _ in .ok },
            fetchPackageList: { _ in
                ["https://github.com/finestructure/Gala",
                 "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"].asURLs
            },
            fetchPackageDenyList: { _ in
                ["https://github.com/daveverwer/LeftPad"].asURLs
            },
            fetchLicense: { _, _ in .init(htmlUrl: "https://github.com/foo/bar/blob/main/LICENSE") },
            fetchMetadata: { _, _ in .mock },
            fetchReadme: { _,  _, _ in .init(html: "readme html", htmlUrl: "readme html url", imagesToCache: []) },
            fetchS3Readme: { _, _, _ in "" },
            fileManager: .mock,
            getStatusCount: { _, _ in eventLoop.future(100) },
            git: .mock,
            githubToken: { nil },
            gitlabApiToken: { nil },
            gitlabPipelineToken: { nil },
            gitlabPipelineLimit: { Constants.defaultGitlabPipelineLimit },
            hideStagingBanner: { false },
            httpClient: { httpClient },
            loadSPIManifest: { _ in nil },
            logger: { logger },
            mastodonCredentials: { nil },
            mastodonPost: { _, _ in },
            metricsPushGatewayUrl: { "http://pushgateway:9091" },
            plausibleBackendReportingSiteID: { nil },
            postPlausibleEvent: { _, _, _, _ in },
            random: Double.random,
            setHTTPClient: { client in Self.httpClient = client },
            setLogger: { logger in Self.logger = logger },
            shell: .mock,
            siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" },
            storeS3Readme: { _, _, _ in "s3ObjectUrl" },
            storeS3ReadmeImages: { _, _ in },
            timeZone: { .utc },
            triggerBuild: { _, _, _, _, _, _, _, _, _ in
                eventLoop.future(.init(status: .ok, webUrl: "http://web_url"))
            }
        )
    }
}
