@testable import App

import XCTVapor


class BuildShowModelTests: XCTestCase {

    func test_buildsURL() throws {
        let m = BuildShow.Model(logs: "logs", repositoryOwner: "owner", repositoryName: "repo")
        XCTAssertEqual(m.buildsURL, "/owner/repo/builds")
    }

}
