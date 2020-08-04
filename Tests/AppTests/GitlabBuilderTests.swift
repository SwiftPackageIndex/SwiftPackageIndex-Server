@testable import App

import XCTest


class GitlabBuilderTests: XCTestCase {
    
    func test_post_trigger() throws {
        Current.builderToken = { "builder token" }
        Current.gitlabPipelineToken = { "pipeline token" }
        Current.siteURL = { "http://example.com" }
        let versionID = UUID()
        
        var called = false
        let client = MockClient { req, res in
            called = true
            // validate
            XCTAssertEqual(try? req.query.decode([String: String].self),
                           .some([
                            "token": "pipeline token",
                            "ref": "main",
                            "variables[API_BASEURL]": "http://example.com/api",
                            "variables[BUILD_PLATFORM]": "macos-spm",
                            "variables[BUILDER_TOKEN]": "builder token",
                            "variables[CLONE_URL]": "https://github.com/daveverwer/LeftPad.git",
                            "variables[REFERENCE]": "1.2.3",
                            "variables[SWIFT_VERSION]": "5.2.4",
                            "variables[VERSION_ID]": versionID.uuidString,
                           ]))
        }
        
        // MUT
        _ = try Gitlab.Builder.postTrigger(client: client,
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
            let swiftVersion = (try? req.query.decode([String: String].self))
                .flatMap { $0["variables[SWIFT_VERSION]"] }
            XCTAssertEqual(swiftVersion, "5.0.3")
        }

        // MUT
        _ = try Gitlab.Builder.postTrigger(client: client,
                                           cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                           platform: .macosSpm,
                                           reference: .tag(.init(1, 2, 3)),
                                           swiftVersion: .v5_0,
                                           versionID: versionID).wait()
        XCTAssertTrue(called)
    }
}
