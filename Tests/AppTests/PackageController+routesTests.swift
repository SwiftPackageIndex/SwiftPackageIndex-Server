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

import Vapor
import XCTest

class PackageController_routesTests: AppTestCase {

    func test_show() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_show_checkingGitHubRepository_notFound() throws {
        Current.fetchHTTPStatusCode = { _ in .notFound }

        // MUT
        try app.test(.GET, "/unknown/package") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_show_checkingGitHubRepository_found() throws {
        Current.fetchHTTPStatusCode = { _ in .ok }

        // MUT
        try app.test(.GET, "/unknown/package") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_show_checkingGitHubRepository_error() throws {
        // Make sure we don't throw an internal server error in case
        // fetchHTTPStatusCode fails
        Current.fetchHTTPStatusCode = { _ in throw FetchError() }

        // MUT
        try app.test(.GET, "/unknown/package") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_ShowModel_packageAvailable() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)

        // MUT
        let model = try await PackageController.ShowModel(db: app.db, owner: "owner", repository: "package")

        // validate
        switch model {
            case .packageAvailable:
                // don't check model details, we simply want to assert the flow logic
                break
            case .packageMissing, .packageDoesNotExist:
                XCTFail("expected package to be available")
        }
    }

    func test_ShowModel_packageMissing() async throws {
        // setup
        Current.fetchHTTPStatusCode = { _ in .ok }

        // MUT
        let model = try await PackageController.ShowModel(db: app.db, owner: "owner", repository: "package")

        // validate
        switch model {
            case .packageAvailable, .packageDoesNotExist:
                XCTFail("expected package to be missing")
            case .packageMissing:
                break
        }
    }

    func test_ShowModel_packageDoesNotExist() async throws {
        // setup
        Current.fetchHTTPStatusCode = { _ in .notFound }

        // MUT
        let model = try await PackageController.ShowModel(db: app.db, owner: "owner", repository: "package")

        // validate
        switch model {
            case .packageAvailable, .packageMissing:
                XCTFail("expected package not to exist")
            case .packageDoesNotExist:
                break
        }
    }

    func test_ShowModel_fetchHTTPStatusCode_error() async throws {
        // setup
        Current.fetchHTTPStatusCode = { _ in throw FetchError() }

        // MUT
        let model = try await PackageController.ShowModel(db: app.db, owner: "owner", repository: "package")

        // validate
        switch model {
            case .packageAvailable, .packageMissing:
                XCTFail("expected package not to exist")
            case .packageDoesNotExist:
                break
        }
    }

    func test_readme() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/readme") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_releases() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/releases") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_builds() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/builds") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_maintainerInfo() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch, packageName: "pkg")
            .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/information-for-package-maintainers") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_maintainerInfo_no_packageName() throws {
        // Ensure we display the page even if packageName is not set
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch, packageName: nil)
            .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/information-for-package-maintainers") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_awsDocumentationURL() throws {
        Current.awsDocsBucket = { "docs-bucket" }
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(owner: "Foo", repository: "Bar", reference: "Main", fragment: .documentation, path: "path").string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/main/documentation/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(owner: "Foo", repository: "Bar", reference: "1.2.3", fragment: .css, path: "path").string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/css/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(owner: "Foo", repository: "Bar", reference: "1.2.3", fragment: .documentation, path: "path").string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/documentation/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(owner: "Foo", repository: "Bar", reference: "1.2.3", fragment: .data, path: "path").string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/data/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(owner: "Foo", repository: "Bar", reference: "1.2.3", fragment: .js, path: "path").string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/js/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(owner: "Foo", repository: "Bar", reference: "1.2.3", fragment: .themeSettings, path: "path").string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/path/theme-settings.json"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(owner: "Foo", repository: "Bar", reference: "1.2.3", fragment: .themeSettings, path: "").string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/theme-settings.json"
        )
    }

    func test_awsDocumentationURL_issue2287() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2287
        // reference with / needs to be escaped
        Current.awsDocsBucket = { "docs-bucket" }
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(owner: "linhay", repository: "SectionKit", reference: "feature/2.0.0", fragment: .documentation, path: "sectionui").string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/linhay/sectionkit/feature-2.0.0/documentation/sectionui"
        )
    }

    func test_canonicalDocumentationUrl() throws {
        // There is no canonical URL for external or universal cases of the canonical target.
        XCTAssertNil(PackageController.canonicalDocumentationUrl(from: "", owner: "", repository: "", fromReference: "",
                                                                 toTarget: .external(url: "https://example.com")))

        XCTAssertNil(PackageController.canonicalDocumentationUrl(from: "", owner: "", repository: "", fromReference: "",
                                                                 toTarget: .universal))

        // There should be no canonical URL if the package owner/repo/ref prefix doesn't match even with a valid canonical target.
        XCTAssertNil(PackageController.canonicalDocumentationUrl(from: "/some/random/url/without/matching/prefix",
                                                                 owner: "owner", repository: "repo", fromReference: "non-canonical-ref",
                                                                 toTarget: .internal(reference: "canonical-ref", archive: "archive")))

        // Switching a non-canonical reference for a canonical one at the root of the documentation
        XCTAssertEqual(PackageController.canonicalDocumentationUrl(from: "/owner/repo/non-canonical-ref/documentation/archive",
                                                                   owner: "owner", repository: "repo", fromReference: "non-canonical-ref",
                                                                   toTarget: .internal(reference: "canonical-ref", archive: "archive")),
                       "/owner/repo/canonical-ref/documentation/archive")

        XCTAssertEqual(PackageController.canonicalDocumentationUrl(from: "/owner/repo/non-canonical-ref/documentation/archive/symbol:$-%",
                                                                   owner: "owner", repository: "repo", fromReference: "non-canonical-ref",
                                                                   toTarget: .internal(reference: "canonical-ref", archive: "archive")),
                       "/owner/repo/canonical-ref/documentation/archive/symbol:$-%")
    }

    func test_defaultDocumentation() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "0123456789",
                    commitDate: .t0,
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .defaultBranch,
                    packageName: "pkg",
                    reference: .branch("main"))
        .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "9876543210",
                    commitDate: .t0,
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .release,
                    packageName: "pkg",
                    reference: .tag(1, 0, 0))
        .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/documentation") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/1.0.0/documentation/docs")
        }
        try app.test(.GET, "/owner/package/documentation/docs/symbol") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/1.0.0/documentation/docs/symbol")
        }
        // There is nothing magic about the catchall - authors need to make sure they point
        // the path after `documentation/` at a valid doc path. We do not try and map it to
        // generated docs (i.e. `docs` in this test) as that would prevent them from
        // cross-target linking.
        // Effectively, all we're doing is inserting the correct `ref` before `documentation`.
        try app.test(.GET, "/owner/package/documentation/foo") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/1.0.0/documentation/foo")
        }
        try app.test(.GET, "/owner/package/documentation/foo#anchor") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/1.0.0/documentation/foo#anchor")
        }
        try app.test(.GET, "/owner/package/documentation/FOO") {
            // Ensure we redirect to lowercase path URLs (which is what DocC generates.
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/1.0.0/documentation/foo")
        }
    }

    func test_documentationRoot_redirect() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "0123456789",
                    commitDate: .t0,
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .defaultBranch,
                    packageName: "pkg",
                    reference: .branch("main"))
        .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "9876543210",
                    commitDate: .t0,
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .release,
                    packageName: "pkg",
                    reference: .tag(1, 0, 0))
        .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/main/documentation") {
            XCTAssertEqual($0.status, .seeOther)
        }
        try app.test(.GET, "/owner/package/1.0.0/documentation") {
            XCTAssertEqual($0.status, .seeOther)
        }
    }

    func test_documentationRoot_noRedirect() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "0123456789",
                    commitDate: .t0,
                    docArchives: [], // No docArchives!
                    latest: .defaultBranch,
                    packageName: "pkg",
                    reference: .branch("main"))
        .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "9876543210",
                    commitDate: .t0,
                    docArchives: [], // No docArchives!
                    latest: .release,
                    packageName: "pkg",
                    reference: .tag(1, 0, 0))
        .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/main/documentation") {
            XCTAssertEqual($0.status, .notFound)
        }
        try app.test(.GET, "/owner/package/1.0.0/documentation") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_documentation() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: "<p>\(uri.path)</p>"))
        }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "0123456789",
                    commitDate: .t0,
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .defaultBranch,
                    packageName: "pkg",
                    reference: .tag(1, 2, 3))
            .save(on: app.db).wait()

        // MUT
        // test path a/b
        try app.test(.GET, "/owner/package/1.2.3/documentation/a/b") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "text/html; charset=utf-8")
            XCTAssertTrue(
                $0.body.asString().contains("<p>/owner/package/1.2.3/documentation/a/b</p>"),
                "was: \($0.body.asString())"
            )
            // Assert body includes the docc.css stylesheet link (as a test that our proxy header injection works)
            XCTAssertTrue($0.body.asString()
                    .contains(#"<link rel="stylesheet" href="/docc.css?test">"#),
                          "was: \($0.body.asString())")
        }

        // Test case insensitive path.
        try app.test(.GET, "/Owner/Package/1.2.3/documentation/a/b") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertTrue(
                $0.body.asString().contains("<p>/owner/package/1.2.3/documentation/a/b</p>"),
                "was: \($0.body.asString())"
            )
        }
        try app.test(.GET, "/owner/package/1.2.3/documentation/A/B") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertTrue(
                $0.body.asString().contains("<p>/owner/package/1.2.3/documentation/a/b</p>"),
                "was: \($0.body.asString())"
            )
        }
    }

    func test_documentation_404() throws {
        // Test conversion of any doc fetching errors into 404s.
        // setup
        Current.fetchDocumentation = { _, uri in .init(status: .badRequest) }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch, packageName: "pkg")
            .save(on: app.db).wait()

        // MUT
        // test base url
        try app.test(.GET, "/owner/package/1.2.3/documentation") {
            XCTAssertEqual($0.status, .notFound)
        }

        // test path a/b
        try app.test(.GET, "/owner/package/1.2.3/documentation/a/b") {
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_documentation_error() throws {
        // Test behaviour when fetchDocumentation throws
        struct SomeError: Error { }
        Current.fetchDocumentation = { _, _ in throw SomeError() }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "123",
                    commitDate: .t0,
                    docArchives: [.init(name: "foo", title: "Foo")],
                    latest: .defaultBranch,
                    packageName: "pkg",
                    reference: .tag(1, 2, 3))
            .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/1.2.3/documentation") {
            // root path doesn't call Current.fetchDocumentation, redirects only
            XCTAssertEqual($0.status, .seeOther)
        }
        try app.test(.GET, "/owner/package/1.2.3/documentation/foo") {
            // hits Current.fetchDocumentation which throws, converted to notFound
            // Regression test for https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2015
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_documentation_css() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: uri.path))
        }

        // MUT
        // test base url
        try app.test(.GET, "/owner/package/1.2.3/css/a") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "text/css")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/css/a")
        }

        // test path a/b
        try app.test(.GET, "/owner/package/1.2.3/css/a/b") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "text/css")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/css/a/b")
        }
    }

    func test_documentation_js() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: uri.path))
        }

        // MUT
        // test base url
        try app.test(.GET, "/owner/package/1.2.3/js/a") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/javascript")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/js/a")
        }

        // test path a/b
        try app.test(.GET, "/owner/package/1.2.3/js/a/b") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/javascript")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/js/a/b")
        }
    }

    func test_documentation_data() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: uri.path))
        }

        // MUT
        // test base url
        try app.test(.GET, "/owner/package/1.2.3/data/a") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/data/a")
        }

        // test path a/b
        try app.test(.GET, "/owner/package/1.2.3/data/a/b") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/data/a/b")
        }

        // test case-insensitivity
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2168
        try app.test(.GET, "/apple/swift-nio/main/data/documentation/NIOCore.json") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual($0.body.asString(),
                           "/apple/swift-nio/main/data/documentation/niocore.json")
        }
    }

    func test_documentation_issue_2287() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2287
        // Ensure references are path encoded
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: "<p>\(uri.path)</p>"))
        }
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "docs", title: "Docs")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("feature/1.2.3"))
        .save(on: app.db)

        // MUT

        // test default path
        try app.test(.GET, "/owner/package/documentation") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/feature-1.2.3/documentation/docs")
        }

        // test reference root path
        try app.test(.GET, "/owner/package/feature-1.2.3/documentation") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/feature-1.2.3/documentation/docs")
        }

        // test path a/b
        try app.test(.GET, "/owner/package/feature-1.2.3/documentation/a/b") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "text/html; charset=utf-8")
            XCTAssertTrue(
                $0.body.asString().contains("<p>/owner/package/feature-1.2.3/documentation/a/b</p>"),
                "was: \($0.body.asString())"
            )
        }
    }

    func test_defaultTutorial() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "0123456789",
                    commitDate: .t0,
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .defaultBranch,
                    packageName: "pkg",
                    reference: .branch("main"))
        .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "9876543210",
                    commitDate: .t0,
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .release,
                    packageName: "pkg",
                    reference: .tag(1, 0, 0))
        .save(on: app.db).wait()

        // MUT
        try app.test(.GET, "/owner/package/tutorials") {
            XCTAssertEqual($0.status, .notFound)
        }
        try app.test(.GET, "/owner/package/tutorials/foo") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/1.0.0/tutorials/foo")
        }
        try app.test(.GET, "/owner/package/tutorials/foo#anchor") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/1.0.0/tutorials/foo#anchor")
        }
    }


    func test_favicon() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok,
                  headers: ["content-type": "application/octet-stream"],
                  body: .init(string: uri.path))
        }

        // MUT
        try app.test(.GET, "/owner/package/1.2.3/favicon.ico") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/favicon.ico")
        }

        try app.test(.GET, "/owner/package/1.2.3/favicon.svg") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/favicon.svg")
        }
    }

    func test_themeSettings() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok,
                  headers: ["content-type": "application/octet-stream"],
                  body: .init(string: uri.path))
        }

        // MUT
        try app.test(.GET, "/owner/package/1.2.3/theme-settings.json") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/theme-settings.json")
        }
    }

    func test_tutorial() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: "<p>\(uri.path)</p>"))
        }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "0123456789",
                    commitDate: Date(timeIntervalSince1970: 0),
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .defaultBranch,
                    packageName: "pkg",
                    reference: .tag(.init(1, 2, 3)))
            .save(on: app.db).wait()

        // MUT
        // test path a/b
        try app.test(.GET, "/owner/package/1.2.3/tutorials/a/b") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "text/html; charset=utf-8")
            XCTAssertTrue(
                $0.body.asString().contains("<p>/owner/package/1.2.3/tutorials/a/b</p>"),
                "was: \($0.body.asString())"
            )
            // Assert body includes the docc.css stylesheet link (as a test that our proxy header injection works)
            XCTAssertTrue($0.body.asString()
                    .contains(#"<link rel="stylesheet" href="/docc.css?test">"#),
                          "was: \($0.body.asString())")
        }

        // Test case insensitive path.
        try app.test(.GET, "/Owner/Package/1.2.3/tutorials/a/b") {
            XCTAssertEqual($0.status, .ok)
        }
    }

    func test_documentationVersionArray_subscriptByReference() throws {
        let updatedAt = Date(timeIntervalSince1970: 0)
        let versions: [DocumentationVersion] = [
            .init(reference: .branch("main"), ownerName: "owner",
                  packageName: "package", docArchives: [], updatedAt: updatedAt),
            .init(reference: .tag(.init(1, 0, 0), "1.0.0"), ownerName: "owner",
                  packageName: "package", docArchives: [], updatedAt: updatedAt),
            .init(reference: .tag(.init(2, 0, 0, "beta1"), "2.0.0-beta1"), ownerName: "owner",
                  packageName: "package", docArchives: [], updatedAt: updatedAt),
            .init(reference: .tag(.init(3, 0, 0), "3.0.0"), ownerName: "owner",
                  packageName: "package", docArchives: [], updatedAt: updatedAt),
        ]

        // MUT
        let versionTwoBeta = try XCTUnwrap(versions[reference: "2.0.0-beta1"])
        let semVer = try XCTUnwrap(versionTwoBeta.reference.semVer)

        XCTAssertEqual(semVer.major, 2)
        XCTAssertEqual(semVer.minor, 0)
        XCTAssertEqual(semVer.patch, 0)
        XCTAssertEqual(semVer.preRelease, "beta1")
        XCTAssertEqual(semVer.build, "")
    }

    func test_documentationVersionArray_latestMajorVersions() throws {
        let updatedAt = Date(timeIntervalSince1970: 0)
        let docs = DocArchive(name: "docs", title: "Docs")
        let versions: [DocumentationVersion] = [
            .init(reference: .branch("main"), ownerName: "owner",
                  packageName: "package", docArchives: [], latest: .defaultBranch, updatedAt: updatedAt),
            .init(reference: .tag(.init(1, 0, 0), "1.0.0"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: nil, updatedAt: updatedAt),
            .init(reference: .tag(.init(1, 0, 1), "1.0.1"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: nil, updatedAt: updatedAt),
            .init(reference: .tag(.init(1, 1, 0), "1.1.0"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: nil, updatedAt: updatedAt),
            .init(reference: .tag(.init(1, 1, 1), "1.1.1"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: nil, updatedAt: updatedAt),
            .init(reference: .tag(.init(1, 1, 2), "1.1.2"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: nil, updatedAt: updatedAt),
            .init(reference: .tag(.init(2, 0, 0), "2.0.0"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: nil, updatedAt: updatedAt),
            .init(reference: .tag(.init(2, 1, 1), "2.1.1"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: nil, updatedAt: updatedAt),
            .init(reference: .tag(.init(3, 0, 0), "3.0.0"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: .release, updatedAt: updatedAt),
            .init(reference: .tag(.init(4, 0, 0, "beta1"), "4.0.0-beta1"), ownerName: "owner",
                  packageName: "package", docArchives: [docs], latest: .preRelease, updatedAt: updatedAt)
        ]

        // MUT
        let latestMajorVersions = versions.latestMajorVersions()
        let latestMajorRerefences = latestMajorVersions.map { "\($0.reference)" }
        print(latestMajorRerefences)

        XCTAssertEqual(latestMajorRerefences, ["1.1.2", "2.1.1", "3.0.0"])
    }

    func test_issue_2288() async throws {
        // Ensures default branch updates don't introduce a "documentation gap"
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2288

        // setup
        let pkg = try savePackage(on: app.db, "bar".asGithubUrl.url, processingStage: .ingestion)
        try await Repository(package: pkg, defaultBranch: "main", name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "docs", title: "Docs")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("main"))
        .save(on: app.db)
        Current.fileManager.fileExists = { path in
            if path.hasSuffix("Package.resolved") { return false }
            return true
        }
        Current.git = .init(
            commitCount: { _ in 2 },
            firstCommitDate: { _ in .t0 },
            lastCommitDate: { _ in .t1 },
            getTags: { _ in [] },
            showDate: { _,_ in fatalError("unused") },
            revisionInfo: { ref, _ in
                if ref == .branch("main") { return .init(commit: "new-commit", date: .t1) }
                fatalError("revisionInfo: \(ref)")
            },
            shortlog: { _ in "2\tauthor" }
        )
        Current.shell.run = { cmd, _ in
            if cmd.string == "swift package dump-package" { return .mockManifest }
            return ""
        }

        // Ensure documentation is resolved
        try app.test(.GET, "/owner/package/documentation") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/main/documentation/docs")
        }

        // Run analyze to detect a new default branch version
        try await Analyze.analyze(client: app.client, database: app.db, logger: app.logger, mode: .limit(1))

        // Confirm that analysis has picked up the new version
        try await XCTAssertEqualAsync(try await Version.query(on: app.db).all().map(\.commit),
                                      ["new-commit"])


        // Ensure documentation is still being resolved
        try app.test(.GET, "/owner/package/documentation") {
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/main/documentation/docs")
        }
    }

}


private struct FetchError: Error { }

private extension HTTPHeaders {
    var location: String? {
        self.first(name: .location)
    }
}

private extension String {
    static let mockManifest = #"""
                    {
                      "name": "bar",
                      "products": [
                        {
                          "name": "p1",
                          "targets": ["t1"],
                          "type": {
                            "executable": null
                          }
                        }
                      ],
                      "targets": [{"name": "t1", "type": "executable"}]
                    }
                    """#
}
