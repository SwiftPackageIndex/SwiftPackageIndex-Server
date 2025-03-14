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

import Foundation

@testable import App

import Dependencies
import Testing


extension AllTests.LiveGitlabBuilderTests {

    @Test(
        .disabled("This is a live trigger test for end-to-end testing of pre-release builder versions")
    )
    func triggerBuild_live() async throws {
        try await withDependencies {
            // make sure environment variables are configured for live access
            $0.environment.awsDocsBucket = { "spi-dev-docs" }
            $0.environment.builderToken = {
                // Set this to a valid value if you want to report build results back to the server
                ProcessInfo.processInfo.environment["LIVE_BUILDER_TOKEN"]
            }
            $0.environment.buildTimeout = { 10 }
            $0.environment.gitlabPipelineToken = {
                // This Gitlab token is required in order to trigger the pipeline
                ProcessInfo.processInfo.environment["LIVE_GITLAB_PIPELINE_TOKEN"]
            }
            $0.environment.siteURL = { "https://staging.swiftpackageindex.com" }
            $0.httpClient = .liveValue
        } operation: {
            // set build branch to trigger on
            Gitlab.Builder.branch = "main"

            let buildId = UUID()

            // use a valid uuid from a live db if reporting back should succeed
            // SemanticVersion 0.3.2 on staging
            let versionID = UUID(uuidString: "93d8c545-15c4-43c2-946f-1b625e2596f9")!

            // MUT
            let res = try await Gitlab.Builder.triggerBuild(
                buildId: buildId,
                cloneURL: "https://github.com/SwiftPackageIndex/SemanticVersion.git",
                isDocBuild: false,
                platform: .macosSpm,
                reference: .tag(.init(0, 3, 2)),
                swiftVersion: .v4,
                versionID: versionID
            )

            print("status: \(res.status)")
            print("buildId: \(buildId)")
            print("webUrl: \(res.webUrl)")
        }
    }

}
