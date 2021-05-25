@testable import App

import Vapor
import XCTest


class GitlabBuilderTests: XCTestCase {

    func test_variables_encoding() throws {
        // Ensure the POST variables are encoded correctly
        // setup
        let app = try setup(.testing)
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
        let versionID = UUID()
        
        var called = false
        let client = MockClient { req, res in
            called = true
            // validate
            XCTAssertEqual(try? req.query.decode(Gitlab.Builder.PostDTO.self),
                           Gitlab.Builder.PostDTO(
                            token: "pipeline token",
                            ref: "main",
                            variables: [
                                "API_BASEURL": "http://example.com/api",
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
                                            cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                            platform: .macosSpm,
                                            reference: .tag(.init(1, 2, 3)),
                                            swiftVersion: .init(5, 2, 4),
                                            versionID: versionID).wait()
        XCTAssertTrue(called)
    }

    func test_issue_588() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/588
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        let versionID = UUID()

        var called = false
        let client = MockClient { req, res in
            called = true
            // validate
            let swiftVersion = (try? req.query.decode(Gitlab.Builder.PostDTO.self))
                .flatMap { $0.variables["SWIFT_VERSION"] }
            XCTAssertEqual(swiftVersion, "5.0")
        }

        // MUT
        _ = try Gitlab.Builder.triggerBuild(client: client,
                                            cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                            platform: .macosSpm,
                                            reference: .tag(.init(1, 2, 3)),
                                            swiftVersion: .v5_0,
                                            versionID: versionID).wait()
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
