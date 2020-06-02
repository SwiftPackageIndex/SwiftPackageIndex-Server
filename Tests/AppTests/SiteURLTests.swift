@testable import App

import Plot
import Vapor
import XCTest


class SiteURLTests: XCTestCase {

    let pkgId: Package.Id = UUID(uuidString: "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")!

    func test_pathComponents_simple() throws {
        let p = SiteURL.privacy.pathComponents
        XCTAssertEqual(p.map(\.description), ["privacy"])
    }

    func test_pathComponents_with_parameter() throws {
        let p = SiteURL.package(.name("id")).pathComponents
        XCTAssertEqual(p.map(\.description), ["packages", ":id"])
    }

    func test_pathComponents_nested() throws {
        let p = SiteURL.api(.version).pathComponents
        XCTAssertEqual(p.map(\.description), ["api", "version"])
    }

    func test_relativeURL() throws {
        XCTAssertEqual(SiteURL.home.relativeURL, "/")
        XCTAssertEqual(SiteURL.images("foo.png").relativeURL, "/images/foo.png")
        XCTAssertEqual(SiteURL.privacy.relativeURL, "/privacy")
    }

    func test_relativeURL_with_parameters() throws {
        XCTAssertEqual(
            SiteURL.package(.value(pkgId)).relativeURL,
            "/packages/CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")
    }

    func test_absoluteURL() throws {
        Current.siteURL = { "https://indexsite.com" }
        XCTAssertEqual(SiteURL.home.absoluteURL, "https://indexsite.com/")
        XCTAssertEqual(SiteURL.images("foo.png").absoluteURL, "https://indexsite.com/images/foo.png")
        XCTAssertEqual(SiteURL.privacy.absoluteURL, "https://indexsite.com/privacy")
    }

}
