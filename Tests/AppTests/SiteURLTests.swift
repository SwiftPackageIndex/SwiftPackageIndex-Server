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

import Dependencies
import Plot
import Testing
import Vapor


extension AllTests.SiteURLTests {

    @Test func pathComponents_simple() throws {
        let p = SiteURL.privacy.pathComponents
        #expect(p.map(\.description) == ["privacy"])
    }

    @Test func pathComponents_with_parameter() throws {
        let p = SiteURL.package(.key, .key, .none).pathComponents
        #expect(p.map(\.description) == [":owner", ":repository"])
    }

    @Test func pathComponents_nested() throws {
        let p = SiteURL.api(.version).pathComponents
        #expect(p.map(\.description) == ["api", "version"])
    }

    @Test func relativeURL() throws {
        #expect(SiteURL.home.relativeURL() == "/")
        #expect(SiteURL.images("foo.png").relativeURL() == "/images/foo.png")
        #expect(SiteURL.privacy.relativeURL() == "/privacy")
    }

    @Test func relativeURL_for_Package() throws {
        #expect(
            SiteURL.package(.value("foo"), .value("bar"), .none).relativeURL() == "/foo/bar")
    }

    @Test func relativeURL_with_anchor() throws {
        #expect(SiteURL.faq.relativeURL(anchor: "hello") == "/faq#hello")
    }

    @Test func relativeURL_with_parameters() throws {
        let url = SiteURL.search.relativeURL(parameters: [
            QueryParameter(key: "c d", value: 2),
            QueryParameter(key: "a b", value: 1)
        ])
        #expect(url == "/search?c%20d=2&a%20b=1")
    }

    @Test func absoluteURL() throws {
        withDependencies {
            $0.environment.siteURL = { "https://indexsite.com" }
        } operation: {
            #expect(SiteURL.home.absoluteURL() == "https://indexsite.com/")
            #expect(SiteURL.images("foo.png").absoluteURL() == "https://indexsite.com/images/foo.png")
            #expect(SiteURL.privacy.absoluteURL() == "https://indexsite.com/privacy")
        }
    }

    @Test func absoluteURL_with_anchor() throws {
        withDependencies {
            $0.environment.siteURL = { "https://indexsite.com" }
        } operation: {
            #expect(SiteURL.faq.absoluteURL(anchor: "hello") == "https://indexsite.com/faq#hello")
        }
    }

    @Test func absoluteURL_with_parameters() throws {
        withDependencies {
            $0.environment.siteURL = { "https://indexsite.com" }
        } operation: {
            let url = SiteURL.rssReleases.absoluteURL(parameters: [
                QueryParameter(key: "c d", value: 2),
                QueryParameter(key: "a b", value: 1)
            ])
            #expect(url == "https://indexsite.com/releases.rss?c%20d=2&a%20b=1")
        }
    }

    @Test func url_escaping() throws {
        withDependencies {
            $0.environment.siteURL = { "https://indexsite.com" }
        } operation: {
            #expect(SiteURL.package(.value("foo bar"), .value("some repo"), .none).absoluteURL() == "https://indexsite.com/foo%20bar/some%20repo")
        }
    }

    @Test func static_relativeURL() throws {
        #expect(SiteURL.relativeURL("foo") == "/foo")
        #expect(SiteURL.relativeURL("/foo") == "/foo")
    }

    @Test func static_absoluteURL() throws {
        withDependencies {
            $0.environment.siteURL = { "https://indexsite.com" }
        } operation: {
            #expect(SiteURL.absoluteURL("foo") == "https://indexsite.com/foo")
            #expect(SiteURL.absoluteURL("/foo") == "https://indexsite.com/foo")
        }
    }

    @Test func api_path() throws {
        #expect(SiteURL.api(.search).path == "api/search")
        #expect(SiteURL.api(.version).path == "api/version")
        do {
            let uuid = UUID()
            #expect(SiteURL.api(.versions(.value(uuid), .buildReport)).path == "api/versions/\(uuid.uuidString)/build-report")
            #expect(SiteURL.api(.builds(.value(uuid), .docReport)).path == "api/builds/\(uuid.uuidString)/doc-report")
        }
    }

    @Test func api_pathComponents() throws {
        #expect(SiteURL.api(.search).pathComponents.map(\.description) == ["api", "search"])
        #expect(SiteURL.api(.version).pathComponents.map(\.description) == ["api", "version"])
        #expect(SiteURL.api(.versions(.key, .buildReport)).pathComponents.map(\.description) == ["api", "versions", ":id", "build-report"])
        #expect(SiteURL.api(.packages(.key, .key, .badge))
                        .pathComponents.map(\.description) == ["api", "packages", ":owner", ":repository", "badge"])
        #expect(SiteURL.api(.packageCollections).pathComponents.map(\.description) == ["api", "package-collections"])
    }

    @Test func apiBaseURL() throws {
        withDependencies {
            $0.environment.siteURL = { "https://example.com" }
        } operation: {
            #expect(SiteURL.apiBaseURL == "https://example.com/api")
        }
    }

    @Test func packageBuildsURL() throws {
        // owner/repo/builds
        #expect(SiteURL.package(.value("foo"), .value("bar"), .builds).path == "foo/bar/builds")
        #expect(SiteURL.package(.key, .key, .builds).pathComponents.map(\.description) == [":owner", ":repository", "builds"])
        // /builds/{id}
        let id = UUID()
        #expect(SiteURL.builds(.value(id)).path == "builds/\(id.uuidString)")
        #expect(SiteURL.builds(.key).pathComponents.map(\.description) == ["builds", ":id"])
    }

    @Test func packageCollectionURL() throws {
        #expect(SiteURL.packageCollectionAuthor(.value("foo")).path == "foo/collection.json")
        #expect(SiteURL.packageCollectionAuthor(.key).pathComponents
                        .map(\.description) == [":owner", "collection.json"])
    }

    @Test func docs() throws {
        #expect(SiteURL.docs(.builds).path == "docs/builds")
        #expect(SiteURL.docs(.builds).pathComponents.map(\.description) == ["docs", "builds"])
    }

    @Test func QueryParameter_encodedForQueryString() {
        // String parameter, no encoding needed
        #expect(QueryParameter(key: "foo", value: "bar").encodedForQueryString == "foo=bar")

        // String parameter, encoding needed
        #expect(QueryParameter(key: "foo", value: "b a r").encodedForQueryString == "foo=b%20a%20r")

        // Integer parameter
        #expect(QueryParameter(key: "foo", value: 1).encodedForQueryString == "foo=1")
    }

    @Test func keywords() throws {
        #expect(SiteURL.keywords(.value("foo")).path == "keywords/foo")
        #expect(SiteURL.keywords(.key).pathComponents.map(\.description) == ["keywords", ":keyword"])
    }

    @Test func collections() throws {
        #expect(SiteURL.collections(.value("foo")).path == "collections/foo")
        #expect(SiteURL.collections(.key).pathComponents.map(\.description) == ["collections", ":key"])
    }

}
