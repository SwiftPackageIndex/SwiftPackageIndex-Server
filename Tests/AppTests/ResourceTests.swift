@testable import App

import Plot
import Vapor
import XCTest


class ResourceTests: XCTestCase {
    let pkgId: Package.Id = UUID(uuidString: "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")!

    func test_pathComponents_simple() throws {
        let p = Root.privacy.pathComponents
        XCTAssertEqual(p.map(\.description), ["privacy"])
    }

    func test_pathComponents_with_parameter() throws {
        let p = Root.package(.name("id")).pathComponents
        XCTAssertEqual(p.map(\.description), ["packages", ":id"])
    }

    func test_pathComponents_nested() throws {
        let p = Root.api(.version).pathComponents
        XCTAssertEqual(p.map(\.description), ["api", "version"])
    }

    func test_href() throws {
        XCTAssertEqual(Root.privacy.absolutePath, "/privacy")
    }

    func test_href_with_parameters() throws {
        XCTAssertEqual(
            Root.package(.value(pkgId)).absolutePath, "/packages/CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")
    }

}
