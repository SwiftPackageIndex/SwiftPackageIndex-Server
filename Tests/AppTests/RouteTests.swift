@testable import App

import SnapshotTesting
import XCTVapor


class RouteTests: SnapshotTestCase {

    func test_wellKnown_appleAppSiteAssociation() throws {
        try app.test(.GET, ".well-known/apple-app-site-association") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType,
                           .some(.init(type: "application", subType: "json")))
            let content = try XCTUnwrap(res.body.asString())
            assertSnapshot(matching: content,
                           as: .init(pathExtension: "json", diffing: .lines))
        }
    }

}
