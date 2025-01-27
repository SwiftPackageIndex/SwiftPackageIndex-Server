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

import XCTest

@testable import App

import Dependencies
import Vapor


class GitlabBuilderTests: AppTestCase {

    func test_SwiftVersion_rendering() throws {
        XCTAssertEqual("\(SwiftVersion.v4)", "6.0.0")
        XCTAssertEqual(SwiftVersion.v4.description(droppingZeroes: .none), "6.0.0")
        XCTAssertEqual(SwiftVersion.v4.description(droppingZeroes: .patch), "6.0")
        XCTAssertEqual(SwiftVersion.v4.description(droppingZeroes: .all), "6")
    }

    func test_variables_encoding() async throws {
        // Ensure the POST variables are encoded correctly
        // setup
        let app = try await setup(.testing)

        try await App.run {
            let req = Request(application: app, on: app.eventLoopGroup.next())
            let dto = Gitlab.Builder.PostDTO(token: "token",
                                             ref: "ref",
                                             variables: ["FOO": "bar"])

            // MUT
            try req.query.encode(dto)

            // validate
            // Gitlab accepts both `variables[FOO]=bar` and `variables%5BFOO%5D=bar` for the [] encoding.
            // Since Vapor 4.92.1 this is now encoded as `variables%5BFOO%5D=bar`.
            XCTAssertEqual(req.url.query?.split(separator: "&").sorted(),
                           ["ref=ref", "token=token", "variables%5BFOO%5D=bar"])
        } defer: {
            try await app.asyncShutdown()
        }
    }

    func test_triggerBuild() async throws {
        let buildId = UUID.id0
        let versionId = UUID.id1
        let called = QueueIsolated(false)
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.siteURL = { "http://example.com" }
            $0.httpClient.post = { @Sendable _, _, body in
                called.setValue(true)
                let body = try XCTUnwrap(body)
                // validate
                XCTAssertEqual(
                    try? URLEncodedFormDecoder().decode(Gitlab.Builder.PostDTO.self, from: body),
                    Gitlab.Builder.PostDTO(
                        token: "pipeline token",
                        ref: "main",
                        variables: [
                            "API_BASEURL": "http://example.com/api",
                            "AWS_DOCS_BUCKET": "docs-bucket",
                            "BUILD_ID": buildId.uuidString,
                            "BUILD_PLATFORM": "macos-spm",
                            "BUILDER_TOKEN": "builder token",
                            "CLONE_URL": "https://github.com/daveverwer/LeftPad.git",
                            "REFERENCE": "1.2.3",
                            "SWIFT_VERSION": "5.2",
                            "TIMEOUT": "10m",
                            "VERSION_ID": versionId.uuidString,
                        ])
                )
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            // MUT
            _ = try await Gitlab.Builder.triggerBuild(buildId: buildId,
                                                      cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                                      isDocBuild: false,
                                                      platform: .macosSpm,
                                                      reference: .tag(.init(1, 2, 3)),
                                                      swiftVersion: .init(5, 2, 4),
                                                      versionID: versionId)
            XCTAssertTrue(called.value)
        }
    }

    func test_issue_588() async throws {
        let called = QueueIsolated(false)
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.environment.builderToken = { "builder token" }
            $0.environment.buildTimeout = { 10 }
            $0.environment.gitlabPipelineToken = { "pipeline token" }
            $0.environment.siteURL = { "http://example.com" }
            $0.httpClient.post = { @Sendable _, _, body in
                called.setValue(true)
                let body = try XCTUnwrap(body)
                // validate
                let swiftVersion = (try? URLEncodedFormDecoder().decode(Gitlab.Builder.PostDTO.self, from: body))
                    .flatMap { $0.variables["SWIFT_VERSION"] }
                XCTAssertEqual(swiftVersion, "6.0")
                return try .created(jsonEncode: Gitlab.Builder.Response(webUrl: "http://web_url"))
            }
        } operation: {
            // MUT
            _ = try await Gitlab.Builder.triggerBuild(buildId: .id0,
                                                      cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                                      isDocBuild: false,
                                                      platform: .macosSpm,
                                                      reference: .tag(.init(1, 2, 3)),
                                                      swiftVersion: .v6_0,
                                                      versionID: .id1)
            XCTAssertTrue(called.value)
        }
    }

    func test_getStatusCount() async throws {
        let page = QueueIsolated(1)
        try await withDependencies {
            $0.environment.gitlabApiToken = { "api token" }
            $0.httpClient.get = { @Sendable url, _ in
                XCTAssertEqual(
                    url,
                    "https://gitlab.com/api/v4/projects/19564054/pipelines?status=pending&page=\(page.value)&per_page=20"
                )
                let pending = #"{"id": 1, "status": "pending"}"#
                defer { page.increment() }
                let elementsPerPage = switch page.value {
                    case 1: 20
                    case 2: 10
                    default:
                        XCTFail("unexpected page: \(page)")
                        throw Abort(.badRequest)
                }
                let list = Array(repeating: pending, count: elementsPerPage).joined(separator: ", ")
                return .ok(body: "[\(list)]")
            }
        } operation: {
            let res = try await Gitlab.Builder.getStatusCount(status: .pending,
                                                              pageSize: 20,
                                                              maxPageCount: 3)
            XCTAssertEqual(res, 30)
        }
    }

}


class LiveGitlabBuilderTests: AppTestCase {

    func test_triggerBuild_live() async throws {
        try XCTSkipIf(
            true,
            "This is a live trigger test for end-to-end testing of pre-release builder versions"
        )

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
