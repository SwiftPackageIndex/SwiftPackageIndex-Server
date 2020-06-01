@testable import App

import Plot
import Vapor
import XCTest


class ResourceTests: XCTestCase {
    let pkgId: Package.Id = UUID(uuidString: "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")!

    func test_url_for() throws {
        do {  // default - relative
            let p = PathComponent.url(for: .privacy)
            XCTAssertEqual(p.description, "privacy")
        }
        do {  // absolute
            let p = PathComponent.url(for: .privacy, relative: false)
            XCTAssertEqual(p.description, "/privacy")
        }
    }

    func test_url_for_with_parameters() throws {
        do {  // default - relative
            let p = PathComponent.url(for: .packages(pkgId))
            XCTAssertEqual(p.description, "packages/CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")
        }
        do {  // absolute
            let p = PathComponent.url(for: .packages(pkgId), relative: false)
            XCTAssertEqual(p.description, "/packages/CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")
        }
    }

    func test_href() throws {
        let href = Node<HTML.LinkContext>.href(.privacy)
        XCTAssertEqual(href.render(), #"href="/privacy""#)
    }

    func test_href_with_parameters() throws {
        let href = Node<HTML.LinkContext>.href(.packages(pkgId))
        XCTAssertEqual(href.render(), #"href="/packages/CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE""#)
    }

}
