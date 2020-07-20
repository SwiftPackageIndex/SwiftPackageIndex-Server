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
                            "variables[BUILD_TOOL]": "xcodebuild",
                            "variables[BUILDER_TOKEN]": "builder token",
                            "variables[CLONE_URL]": "https://github.com/daveverwer/LeftPad.git",
                            "variables[PLATFORM_NAME]": "unknown",
                            "variables[PLATFORM_VERSION]": "test",
                            "variables[REFERENCE]": "1.2.3",
                            "variables[SWIFT_VERSION]": "5.2.4",
                            "variables[VERSION_ID]": versionID.uuidString,
                           ]))
        }
        
        // MUT
        _ = try Gitlab.Builder.postTrigger(client: client,
                                           buildTool: .xcodebuild,
                                           cloneURL: "https://github.com/daveverwer/LeftPad.git",
                                           platform: .init(name: .unknown, version: "test"),
                                           reference: .tag(.init(1, 2, 3)),
                                           swiftVersion: .init(5, 2, 4),
                                           versionID: versionID).wait()
        XCTAssertTrue(called)
    }
    
}
