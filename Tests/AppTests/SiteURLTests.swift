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
        let p = SiteURL.package(.key, .key, .none).pathComponents
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
            SiteURL.package(.value("foo"), .value("bar"), .none).relativeURL(),
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
    
    func test_absoluteURL_with_parameters() throws {
        Current.siteURL = { "https://indexsite.com" }
        XCTAssertEqual(SiteURL.rssReleases.absoluteURL(parameters: ["c d": "2", "a b": "1"]),
                       "https://indexsite.com/releases.rss?a%20b=1&c%20d=2")
    }
    
    func test_url_escaping() throws {
        Current.siteURL = { "https://indexsite.com" }
        XCTAssertEqual(SiteURL.package(.value("foo bar"), .value("some repo"), .none).absoluteURL(),
                       "https://indexsite.com/foo%20bar/some%20repo")
    }
    
    func test_static_relativeURL() throws {
        XCTAssertEqual(SiteURL.relativeURL("foo"), "/foo")
        XCTAssertEqual(SiteURL.relativeURL("/foo"), "/foo")
    }
    
    func test_static_absoluteURL() throws {
        Current.siteURL = { "https://indexsite.com" }
        XCTAssertEqual(SiteURL.absoluteURL("foo"), "https://indexsite.com/foo")
        XCTAssertEqual(SiteURL.absoluteURL("/foo"), "https://indexsite.com/foo")
    }
    
    func test_api_path() throws {
        XCTAssertEqual(SiteURL.api(.search).path, "api/search")
        XCTAssertEqual(SiteURL.api(.version).path, "api/version")
        do {
            let uuid = UUID()
            XCTAssertEqual(SiteURL.api(.versions(.value(uuid), .builds)).path,
                           "api/versions/\(uuid.uuidString)/builds")
            XCTAssertEqual(SiteURL.api(.versions(.value(uuid), .triggerBuild)).path,
                           "api/versions/\(uuid.uuidString)/trigger-build")
        }
    }
    
    func test_api_pathComponents() throws {
        XCTAssertEqual(SiteURL.api(.search).pathComponents.map(\.description), ["api", "search"])
        XCTAssertEqual(SiteURL.api(.version).pathComponents.map(\.description), ["api", "version"])
        XCTAssertEqual(SiteURL.api(.versions(.key, .builds)).pathComponents.map(\.description),
                       ["api", "versions", ":id", "builds"])
        XCTAssertEqual(SiteURL.api(.versions(.key, .triggerBuild)).pathComponents.map(\.description),
                       ["api", "versions", ":id", "trigger-build"])
        XCTAssertEqual(SiteURL.api(.packages(.key, .key, .triggerBuilds))
                        .pathComponents.map(\.description),
                       ["api", "packages", ":owner", ":repository", "trigger-builds"])
    }
    
    func test_apiBaseURL() throws {
        Current.siteURL = { "http://example.com" }
        XCTAssertEqual(SiteURL.apiBaseURL, "http://example.com/api")
    }

    func test_packageBuildsURL() throws {
        // owner/repo/builds
        XCTAssertEqual(SiteURL.package(.value("foo"), .value("bar"), .builds).path,
                       "foo/bar/builds")
        XCTAssertEqual(SiteURL.package(.key, .key, .builds).pathComponents.map(\.description),
                       [":owner", ":repository", "builds"])
        // /builds/{id}
        let id = UUID()
        XCTAssertEqual(SiteURL.builds(.value(id)).path, "builds/\(id.uuidString)")
        XCTAssertEqual(SiteURL.builds(.key).pathComponents.map(\.description), ["builds", ":id"])
    }
}
