@testable import App

import Plot
import Vapor
import XCTest


class SiteURLTests: XCTestCase {

    func test_pathComponents_simple() throws {
        let p = SiteURL.privacy.pathComponents
        XCTAssertEqual(p.map(\.description), ["privacy"])
    }

    func test_pathComponents_with_parameter() throws {
        let p = SiteURL.package(.name("owner"), .name("repository")).pathComponents
        XCTAssertEqual(p.map(\.description), [":owner", ":repository"])
    }

    func test_pathComponents_nested() throws {
        let p = SiteURL.api(.version).pathComponents
        XCTAssertEqual(p.map(\.description), ["api", "version"])
    }

    func test_relativeURL() throws {
        XCTAssertEqual(SiteURL.home.relativeURL(), "/")
        XCTAssertEqual(SiteURL.images("foo.png").relativeURL(), "/images/foo.png")
        XCTAssertEqual(SiteURL.privacy.relativeURL(), "/privacy")
    }

    func test_relativeURL_with_parameters() throws {
        XCTAssertEqual(
            SiteURL.package(.value("foo"), .value("bar")).relativeURL(),
            "/foo/bar")
    }

    func test_relativeURL_with_anchor() throws {
        XCTAssertEqual(SiteURL.faq.relativeURL(anchor: "hello"), "/faq#hello")
    }

    func test_absoluteURL() throws {
        Current.siteURL = { "https://indexsite.com" }
        XCTAssertEqual(SiteURL.home.absoluteURL(), "https://indexsite.com/")
        XCTAssertEqual(SiteURL.images("foo.png").absoluteURL(), "https://indexsite.com/images/foo.png")
        XCTAssertEqual(SiteURL.privacy.absoluteURL(), "https://indexsite.com/privacy")
    }

    func test_absoluteURL_with_anchor() throws {
        Current.siteURL = { "https://indexsite.com" }
        XCTAssertEqual(SiteURL.faq.absoluteURL(anchor: "hello"), "https://indexsite.com/faq#hello")
    }

    func test_url_escaping() throws {
        Current.siteURL = { "https://indexsite.com" }
        XCTAssertEqual(SiteURL.package(.value("foo bar"), .value("some repo")).absoluteURL(),
                       "https://indexsite.com/foo%20bar/some%20repo")
    }

}
