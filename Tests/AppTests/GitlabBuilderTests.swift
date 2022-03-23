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

import Vapor
import XCTest


class GitlabBuilderTests: XCTestCase {

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
        XCTAssertEqual(req.url.query?.split(separator: "&").sorted(),
                       ["ref=ref", "token=token", "variables[FOO]=bar"])
    }

    func test_triggerBuild() throws {
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
                                "BUILD_ID": buildId.uuidString,
                                "BUILD_PLATFORM": "macos-spm",
                                "BUILDER_TOKEN": "builder token",
                                "CLONE_URL": "https://github.com/daveverwer/LeftPad.git",
                                "REFERENCE": "1.2.3",
                                "SWIFT_VERSION": "5.2",
                                "VERSION_ID": versionID.uuidString,
                            ]))
        }
        
        // MUT
        _ = try Gitlab.Builder.triggerBuild(client: client,
                                            buildId: buildId,
                                            cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                            platform: .macosSpm,
                                            reference: .tag(.init(1, 2, 3)),
                                            swiftVersion: .init(5, 2, 4),
                                            versionID: versionID).wait()
        XCTAssertTrue(called)
    }

    func test_issue_588() throws {
        #if compiler(<6)
            throw XCTSkip()
        #else
            // See: https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/588
            XCTFail("Once Swift 6.0 is released this test needs fixing up. It was tempoorarily removed when we removed support for Swift 5.0.")

            // Current.builderToken = { "builder token" }
            // Current.gitlabPipelineToken = { "pipeline token" }
            // Current.siteURL = { "http://example.com" }
            // let versionID = UUID()
            //
            // var called = false
            // let client = MockClient { req, res in
            //     called = true
            //     try? res.content.encode(
            //         Gitlab.Builder.Response.init(webUrl: "http://web_url")
            //     )
            //     // validate
            //     let swiftVersion = (try? req.query.decode(Gitlab.Builder.PostDTO.self))
            //         .flatMap { $0.variables["SWIFT_VERSION"] }
            //     XCTAssertEqual(swiftVersion, "5.0")
            // }
            //
            // // MUT
            // _ = try Gitlab.Builder.triggerBuild(client: client,
            //                                     cloneURL: "https://github.com/daveverwer/LeftPad.git",
            //                                     platform: .macosSpm,
            //                                     reference: .tag(.init(1, 2, 3)),
            //                                     swiftVersion: .v5_0,
            //                                     versionID: versionID).wait()
            // XCTAssertTrue(called)
        #endif
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
