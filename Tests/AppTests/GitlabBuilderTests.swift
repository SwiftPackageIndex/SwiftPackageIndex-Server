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

import Vapor
import XCTest


class GitlabBuilderTests: AppTestCase {

    func test_variables_encoding() async throws {
        // Ensure the POST variables are encoded correctly
        // setup
        let app = try await setup(.testing)
        defer { app.shutdown() }
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
    }

    func test_triggerBuild() throws {
        Current.awsDocsBucket = { "docs-bucket" }
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        let buildId = UUID()
        let versionID = UUID()

        var called = false
        let client = MockClient { req, res in
            called = true
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
            // validate
            XCTAssertEqual(try? req.query.decode(Gitlab.Builder.PostDTO.self),
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
                                "VERSION_ID": versionID.uuidString,
                            ]))
        }

        // MUT
        _ = try Gitlab.Builder.triggerBuild(client: client,
                                            buildId: buildId,
                                            cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                            isDocBuild: false,
                                            platform: .macosSpm,
                                            reference: .tag(.init(1, 2, 3)),
                                            swiftVersion: .init(5, 2, 4),
                                            versionID: versionID).wait()
        XCTAssertTrue(called)
    }

    func test_issue_588() throws {
        Current.awsDocsBucket = { "docs-bucket" }
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }

        var called = false
        let client = MockClient { req, res in
            called = true
            try? res.content.encode(
                Gitlab.Builder.Response.init(webUrl: "http://web_url")
            )
            // validate
            let swiftVersion = (try? req.query.decode(Gitlab.Builder.PostDTO.self))
                .flatMap { $0.variables["SWIFT_VERSION"] }
            XCTAssertEqual(swiftVersion, "6.0")
        }

        // MUT
        _ = try Gitlab.Builder.triggerBuild(client: client,
                                            buildId: .id0,
                                            cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                            isDocBuild: false,
                                            platform: .macosSpm,
                                            reference: .tag(.init(1, 2, 3)),
                                            swiftVersion: .v6_0,
                                            versionID: .id1).wait()
        XCTAssertTrue(called)
    }

    func test_getStatusCount() throws {
        Current.gitlabApiToken = { "api token" }
        Current.gitlabPipelineToken = { nil }

        var page = 1
        let client = MockClient { req, res in
            XCTAssertEqual(req.url.string, "https://gitlab.com/api/v4/projects/19564054/pipelines?status=pending&page=\(page)&per_page=20")
            res.status = .ok
            let pending = #"{"id": 1, "status": "pending"}"#
            switch page {
                case 1:
                    let list = Array(repeating: pending, count: 20).joined(separator: ", ")
                    res.body = makeBody("[\(list)]")
                case 2:
                    let list = Array(repeating: pending, count: 10).joined(separator: ", ")
                    res.body = makeBody("[\(list)]")
                default:
                    XCTFail("unexpected page: \(page)")
            }
            page += 1
        }

        let res = try Gitlab.Builder.getStatusCount(client: client,
                                                    status: .pending,
                                                    pageSize: 20,
                                                    maxPageCount: 3).wait()
        XCTAssertEqual(res, 30)
    }

}


class LiveGitlabBuilderTests: AppTestCase {

    func test_triggerBuild_live() async throws {
        try XCTSkipIf(
            true,
            "This is a live trigger test for end-to-end testing of pre-release builder versions"
        )

        // set build branch to trigger on
        Gitlab.Builder.branch = "main"

        // make sure environment variables are configured for live access
        Current.awsDocsBucket = { "spi-dev-docs" }
        Current.builderToken = {
            // Set this to a valid value if you want to report build results back to the server
            ProcessInfo.processInfo.environment["LIVE_BUILDER_TOKEN"]
        }
        Current.gitlabPipelineToken = {
            // This Gitlab token is required in order to trigger the pipeline
            ProcessInfo.processInfo.environment["LIVE_GITLAB_PIPELINE_TOKEN"]
        }
        Current.siteURL = { "https://staging.swiftpackageindex.com" }

        let buildId = UUID()

        // use a valid uuid from a live db if reporting back should succeed
        // SemanticVersion 0.3.2 on staging
        let versionID = UUID(uuidString: "93d8c545-15c4-43c2-946f-1b625e2596f9")!

        // MUT
        let res = try await Gitlab.Builder.triggerBuild(
            client: app.client,
            buildId: buildId,
            cloneURL: "https://github.com/SwiftPackageIndex/SemanticVersion.git",
            isDocBuild: false,
            platform: .macosSpm,
            reference: .tag(.init(0, 3, 2)),
            swiftVersion: .v4,
            versionID: versionID).get()

        print("status: \(res.status)")
        print("buildId: \(buildId)")
        print("webUrl: \(res.webUrl)")
    }

}
