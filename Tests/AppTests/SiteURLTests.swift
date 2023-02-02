// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

    func test_relativeURL_for_Package() throws {
        XCTAssertEqual(
            SiteURL.package(.value("foo"), .value("bar"), .none).relativeURL(),
            "/foo/bar")
    }

    func test_relativeURL_with_anchor() throws {
        XCTAssertEqual(SiteURL.faq.relativeURL(anchor: "hello"), "/faq#hello")
    }

    func test_relativeURL_with_parameters() throws {
        let url = SiteURL.search.relativeURL(parameters: [
            QueryParameter(key: "c d", value: 2),
            QueryParameter(key: "a b", value: 1)
        ])
        XCTAssertEqual(url, "/search?c%20d=2&a%20b=1")
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
        let url = SiteURL.rssReleases.absoluteURL(parameters: [
            QueryParameter(key: "c d", value: 2),
            QueryParameter(key: "a b", value: 1)
        ])
        XCTAssertEqual(url, "https://indexsite.com/releases.rss?c%20d=2&a%20b=1")
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
            XCTAssertEqual(SiteURL.api(.versions(.value(uuid), .buildReport)).path,
                           "api/versions/\(uuid.uuidString)/buildReport")
            XCTAssertEqual(SiteURL.api(.builds(.value(uuid), .docReport)).path,
                           "api/builds/\(uuid.uuidString)/docReport")
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
        XCTAssertEqual(SiteURL.api(.packages(.key, .key, .badge))
                        .pathComponents.map(\.description),
                       ["api", "packages", ":owner", ":repository", "badge"])
        XCTAssertEqual(SiteURL.api(.packageCollections).pathComponents.map(\.description),
                       ["api", "package-collections"])
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

    func test_packageCollectionURL() throws {
        XCTAssertEqual(SiteURL.packageCollection(.value("foo")).path,
                       "foo/collection.json")
        XCTAssertEqual(SiteURL.packageCollection(.key).pathComponents
                        .map(\.description),
                       [":owner", "collection.json"])
    }

    func test_docs() throws {
        XCTAssertEqual(SiteURL.docs(.builds).path, "docs/builds")
        XCTAssertEqual(SiteURL.docs(.builds).pathComponents.map(\.description), ["docs", "builds"])
    }

    func test_QueryParameter_encodedForQueryString() {
        // String parameter, no encoding needed
        XCTAssertEqual(QueryParameter(key: "foo", value: "bar").encodedForQueryString, "foo=bar")

        // String parameter, encoding needed
        XCTAssertEqual(QueryParameter(key: "foo", value: "b a r").encodedForQueryString, "foo=b%20a%20r")

        // Integer parameter
        XCTAssertEqual(QueryParameter(key: "foo", value: 1).encodedForQueryString, "foo=1")
    }

    func test_keywords() throws {
        XCTAssertEqual(SiteURL.keywords(.value("foo")).path, "keywords/foo")
        XCTAssertEqual(SiteURL.keywords(.key).pathComponents.map(\.description), ["keywords", ":keyword"])
    }

}
