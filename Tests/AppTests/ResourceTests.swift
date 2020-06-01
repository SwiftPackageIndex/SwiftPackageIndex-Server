@testable import App

import Plot
import Vapor
import XCTest


class ResourceTests: XCTestCase {
    let pkgId: Package.Id = UUID(uuidString: "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")!

    func test_path() throws {
        let p = PathComponent.path(for: .privacy)
        XCTAssertEqual(p.map(\.description), ["privacy"])
    }

    func test_path_with_parameter() throws {
        let p = PathComponent.path(for: .package(.name("id")))
        XCTAssertEqual(p.map(\.description), ["packages", ":id"])
    }

    func test_href() throws {
        let href = Node<HTML.LinkContext>.href(.privacy)
        XCTAssertEqual(href.render(), #"href="/privacy""#)
    }

    func test_href_with_parameters() throws {
        let href = Node<HTML.LinkContext>.href(.package(.value(pkgId)))
        XCTAssertEqual(href.render(), #"href="/packages/CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE""#)
    }

}
