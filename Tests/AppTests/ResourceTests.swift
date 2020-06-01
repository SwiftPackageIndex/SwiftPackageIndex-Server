@testable import App

import Plot
import Vapor
import XCTest


class ResourceTests: XCTestCase {
    let pkgId: Package.Id = UUID(uuidString: "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")!

    func test_path() throws {
        let p = PathComponent.path(for: Root.privacy)
        XCTAssertEqual(p.map(\.description), ["privacy"])
    }

    func test_path_with_parameter() throws {
        let p = PathComponent.path(for: Root.package(.name("id")))
        XCTAssertEqual(p.map(\.description), ["packages", ":id"])
    }

    func test_path_nested() throws {
        let p = PathComponent.path(for: Root.api(.version))
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
