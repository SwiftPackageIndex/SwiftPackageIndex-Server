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

import XCTest

@testable import App

import SnapshotTesting
import SwiftSoup
import Vapor


class PackageController_routesTests: SnapshotTestCase {

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

    func test_readme_route() async throws {
        // Test that readme route is set up
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)

        // MUT
        try await app.test(.GET, "/owner/package/readme") { res async in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func test_readme_basic() async throws {
        // Test readme fragment happy path
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, defaultBranch: "main", name: "package", owner: "owner", readmeHtmlUrl: "html url")
            .save(on: app.db)
        try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)
        let req = Request(application: app, on: app.eventLoopGroup.next())
        req.parameters.set("owner", to: "owner")
        req.parameters.set("repository", to: "package")
        Current.fetchS3Readme = { _, _, _ in #"<div id="readme"><article>readme content</article></div>"# }

        // MUT
        let node = try await PackageController.readme(req: req)

        // validate
        XCTAssertEqual(node.render(indentedBy: .spaces(2)),
            """
            <turbo-frame id="readme_content">readme content</turbo-frame>
            """)
    }

    func test_readme_no_readmeHtmlUrl() async throws {
        // Test readme fragment when there's no readme html url
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner", readmeHtmlUrl: nil)
            .save(on: app.db)
        try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)
        let req = Request(application: app, on: app.eventLoopGroup.next())
        req.parameters.set("owner", to: "owner")
        req.parameters.set("repository", to: "package")
        Current.fetchS3Readme = { _, _, _ in
            XCTFail("must not be called")
            return ""
        }

        // MUT
        let node = try await PackageController.readme(req: req)

        // validate
        XCTAssertEqual(node.render(indentedBy: .spaces(2)),
            """
            <turbo-frame id="readme_content">
              <p>This package does not have a README file.</p>
            </turbo-frame>
            """)
    }

    func test_readme_error() async throws {
        // Test readme fragment when fetchS3Readme throws
        // setup
        struct Error: Swift.Error { }
        Current.fetchS3Readme = { _, _, _ in throw Error() }
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg,
                             name: "package",
                             owner: "owner",
                             readmeHtmlUrl: "html url",
                             s3Readme: .cached(s3ObjectUrl: "", githubEtag: "")
        ).save(on: app.db)
        try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)
        let req = Request(application: app, on: app.eventLoopGroup.next())
        req.parameters.set("owner", to: "owner")
        req.parameters.set("repository", to: "package")

        // MUT
        let node = try await PackageController.readme(req: req)

        // validate
        XCTAssertEqual(node.render(indentedBy: .spaces(2)),
            """
            <turbo-frame id="readme_content">
              <p>This package's README file couldn't be loaded. Try 
                <a href="html url">viewing it on GitHub</a>.
              </p>
            </turbo-frame>
            """)
        let app = self.app!
        try await XCTAssertEqualAsync(try await Repository.query(on: app.db).count(), 1)
        let s3Readme = try await XCTUnwrapAsync(try await Repository.query(on: app.db).first()?.s3Readme)
        XCTAssert(s3Readme.isError)
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

    func test_DocRoute_baseURL() throws {
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .documentation).baseURL,
            "foo/bar/1.2.3"
        )
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .css).baseURL,
            "foo/bar/1.2.3"
        )
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("main"), fragment: .documentation).baseURL,
            "foo/bar/main"
        )
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("Main"), fragment: .documentation).baseURL,
            "foo/bar/main"
        )
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("feature/a"), fragment: .documentation).baseURL,
            "foo/bar/feature-a"
        )
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "1.2.3"), fragment: .documentation).baseURL,
            "foo/bar/1.2.3"
        )
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "1.2.3"), fragment: .documentation).baseURL,
            "foo/bar/1.2.3"
        )
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "main"), fragment: .documentation).baseURL,
            "foo/bar/main"
        )
        XCTAssertEqual(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "Main"), fragment: .documentation).baseURL,
            "foo/bar/main"
        )
    }

    func test_awsDocumentationURL() throws {
        Current.awsDocsBucket = { "docs-bucket" }
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("Main"), fragment: .documentation, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/main/documentation/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .css, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/css/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .documentation, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/documentation/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .data, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/data/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .js, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/js/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .linkablePaths, pathElements: [""])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/linkable-paths.json"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .linkablePaths, pathElements: ["ignored"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/linkable-paths.json"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .themeSettings, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/path/theme-settings.json"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .themeSettings, pathElements: [""])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/theme-settings.json"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("feature/a"), fragment: .documentation, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/feature-a/documentation/path"
        )
    }

    func test_awsDocumentationURL_current() throws {
        Current.awsDocsBucket = { "docs-bucket" }
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "Main"), fragment: .documentation, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/main/documentation/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "1.2.3"), fragment: .documentation, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/documentation/path"
        )
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "feature/a"), fragment: .documentation, pathElements: ["path"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/feature-a/documentation/path"
        )

    }

    func test_awsDocumentationURL_issue2287() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2287
        // reference with / needs to be escaped
        Current.awsDocsBucket = { "docs-bucket" }
        XCTAssertEqual(
            try PackageController.awsDocumentationURL(route: .init(owner: "linhay", repository: "SectionKit", docVersion: .reference("feature/2.0.0"), fragment: .documentation, pathElements: ["sectionui"])).string,
            "http://docs-bucket.s3-website.us-east-2.amazonaws.com/linhay/sectionkit/feature-2.0.0/documentation/sectionui"
        )
    }

    func test_canonicalDocumentationUrl() throws {
        // There is no canonical URL for external or universal cases of the canonical target.
        XCTAssertNil(PackageController.canonicalDocumentationUrl(fromUrlPath: "", owner: "", repository: ""))

        // Switching a non-canonical reference for a canonical one at the root of the documentation.
        XCTAssertEqual(PackageController.canonicalDocumentationUrl(fromUrlPath: "/owner/repo/non-canonical-ref/documentation/archive",
                                                                   owner: "owner",
                                                                   repository: "repo"),
                       "http://localhost:8080/owner/repo/~/documentation/archive")

        // Same test but with a symbol.
        XCTAssertEqual(PackageController.canonicalDocumentationUrl(fromUrlPath: "/owner/repo/non-canonical-ref/documentation/archive/symbol:$-%",
                                                                   owner: "owner",
                                                                   repository: "repo"),
                       "http://localhost:8080/owner/repo/~/documentation/archive/symbol:$-%")
    }

    func test_documentation_routes_redirect() async throws {
        // Test the redirect documentation routes without any reference:
        //   /owner/package/documentation + various path elements
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("main"))
        .save(on: app.db)
        try await Version(package: pkg,
                          commit: "9876543210",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .release,
                          packageName: "pkg",
                          reference: .tag(1, 0, 0))
        .save(on: app.db)

        // MUT
        try await app.test(.GET, "/owner/package/documentation") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/documentation/target")
        }
        try await app.test(.GET, "/owner/package/documentation/target/symbol") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/documentation/target/symbol")
        }
        // We do not validate the catchall - authors need to make sure they point
        // the path after `documentation/` at a valid doc path. We do not try and map it to
        // generated docs (i.e. `target` in this test) as that would prevent them from
        // cross-target linking.
        // Effectively, all we're doing is inserting the correct `ref` before `documentation`.
        try await app.test(.GET, "/owner/package/documentation/foo") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/documentation/foo")
        }
        try await app.test(.GET, "/owner/package/documentation/foo#anchor") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/documentation/foo#anchor")
        }
        try await app.test(.GET, "/owner/package/documentation/FOO") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/documentation/foo")
        }
        try await app.test(.GET, "/owner/package/tutorials/foo") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/tutorials/foo")
        }
    }

    func test_documentation_routes_current() async throws {
        // Test the current (~) documentation routes:
        //   /owner/package/documentation/~ + various path elements
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("main"))
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "9876543210",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .release,
                          packageName: "pkg",
                          reference: .tag(1, 0, 0))
            .save(on: app.db)
        Current.fetchDocumentation = { _, _ in .init(status: .ok, body: .mockIndexHTML()) }

        // MUT

        // test partially qualified route (no archive)
        try await app.test(.GET, "/owner/package/~/documentation") { @Sendable res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/documentation/target")
        }

        // test fully qualified route
        try await app.test(.GET, "/owner/package/~/documentation/target") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/~/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
            XCTAssertFalse(body.contains(#"<link rel="canonical""#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.0.0</span>"#))
        }

        // test catchall
        try await app.test(.GET, "/owner/package/~/documentation/target/a/b#anchor") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/~/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
            XCTAssertFalse(body.contains(#"<link rel="canonical""#))
            XCTAssertFalse(body.contains(#"a/b#anchor"#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.0.0</span>"#))
        }

        // Test case insensitive path.
        try await app.test(.GET, "/Owner/Package/~/documentation/target/A/b#anchor") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index-mixed-case")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/~/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
            XCTAssertFalse(body.contains(#"<link rel="canonical""#))
            XCTAssertFalse(body.contains(#"a/b#anchor"#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.0.0</span>"#))
        }
    }

    func test_documentation_routes_current_rewrite() async throws {
        // Test the current (~) documentation routes with baseURL rewriting:
        //   /owner/package/documentation/~ + various path elements
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("main"))
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "9876543210",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .release,
                          packageName: "pkg",
                          reference: .tag(1, 0, 0))
            .save(on: app.db)
        Current.fetchDocumentation = { _, _ in .init(status: .ok, body: .mockIndexHTML(baseURL: "/owner/package/1.0.0")) }

        // MUT

        // test fully qualified route
        try await app.test(.GET, "/owner/package/~/documentation/target") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/~/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
            XCTAssertFalse(body.contains(#"<link rel="canonical""#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.0.0</span>"#))
        }

        // test catchall
        try await app.test(.GET, "/owner/package/~/documentation/target/a/b#anchor") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
            XCTAssertFalse(body.contains(#"<link rel="canonical""#))
            XCTAssertFalse(body.contains(#"a/b#anchor"#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.0.0</span>"#))
        }

        // Test case insensitive path.
        try await app.test(.GET, "/Owner/Package/~/documentation/target/A/b#anchor") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index-mixed-case")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
            XCTAssertFalse(body.contains(#"<link rel="canonical""#))
            XCTAssertFalse(body.contains(#"a/b#anchor"#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.0.0</span>"#))
        }
    }

    func test_documentation_routes_ref() async throws {
        // Test the documentation routes with a reference:
        //   /owner/package/documentation/{reference} + various path elements
        // setup
        let pkg = try await savePackageAsync(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("main"))
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "9876543210",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .release,
                          packageName: "pkg",
                          reference: .tag(1, 2, 3))
            .save(on: app.db)
        Current.fetchDocumentation = { _, _ in .init(status: .ok, body: .mockIndexHTML()) }

        // MUT

        // test partially qualified route (no archive)
        try await app.test(.GET, "/owner/package/1.2.3/documentation") { @Sendable res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.2.3/documentation/target")
        }

        // test fully qualified route
        try await app.test(.GET, "/owner/package/1.2.3/documentation/target") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index-target")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/1.2.3/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/1.2.3/favicon.ico" />"#))
            XCTAssert(body.contains(#"<link rel="canonical" href="/owner/package/1.2.3/documentation/target" />"#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.2.3</span>"#))
        }

        // test catchall
        try await app.test(.GET, "/owner/package/1.2.3/documentation/target/a/b#anchor") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index-target-a-b")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/1.2.3/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/1.2.3/favicon.ico" />"#))
            XCTAssert(body.contains(#"<link rel="canonical" href="/owner/package/1.2.3/documentation/target/a/b#anchor" />"#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.2.3</span>"#))
        }

        // Test case insensitive path.
        try await app.test(.GET, "/Owner/Package/1.2.3/documentation/target/A/b#Anchor") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index-target-a-b-mixed-case")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/1.2.3/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/1.2.3/favicon.ico" />"#))
            XCTAssert(body.contains(#"<link rel="canonical" href="/owner/package/1.2.3/documentation/target/A/b#Anchor" />"#))
            XCTAssert(body.contains(#"Documentation for <span class="stable">1.2.3</span>"#))
        }
    }

    func test_documentation_routes_no_archive() async throws {
        // Test documentation routes when no archive is in the path
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("main"))
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "9876543210",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .release,
                          packageName: "pkg",
                          reference: .tag(1, 0, 0))
            .save(on: app.db)
        Current.fetchDocumentation = { _, _ in .init(status: .ok, body: .mockIndexHTML()) }

        // MUT
        try await app.test(.GET, "/owner/package/main/documentation") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/main/documentation/target")
        }
        try await app.test(.GET, "/owner/package/1.0.0/documentation") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/documentation/target")
        }
        try await app.test(.GET, "/owner/package/~/documentation") { res async in
            XCTAssertEqual(res.status, .seeOther)
            XCTAssertEqual(res.headers.location, "/owner/package/1.0.0/documentation/target")
        }
    }

    func test_documentationRoot_notFound() throws {
        // setup
        Current.fetchDocumentation = { _, _ in .init(status: .notFound) }
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
            XCTAssertEqual($0.status, .seeOther)
            XCTAssertEqual($0.headers.location, "/owner/package/1.2.3/documentation/foo")
        }
        try app.test(.GET, "/owner/package/1.2.3/documentation/foo") {
            // hits Current.fetchDocumentation which throws, converted to notFound
            // Regression test for https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2015
            XCTAssertEqual($0.status, .notFound)
        }
    }

    func test_documentation_current_css() async throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: uri.path))
        }
        let pkg = try await savePackageAsync(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          reference: .branch("main"))
            .save(on: app.db)

        // MUT
        // test base url
        try await app.test(.GET, "/owner/package/~/css/a") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/css")
            XCTAssertEqual(res.body.asString(), "/owner/package/main/css/a")
        }

        // test path a/b
        try await app.test(.GET, "/owner/package/~/css/a/b") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/css")
            XCTAssertEqual(res.body.asString(), "/owner/package/main/css/a/b")
        }
    }

    func test_documentation_ref_css() throws {
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

    func test_documentation_current_js() async throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: uri.path))
        }
        let pkg = try await savePackageAsync(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          reference: .branch("main"))
            .save(on: app.db)

        // MUT
        // test base url
        try await app.test(.GET, "/owner/package/~/js/a") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "application/javascript")
            XCTAssertEqual(res.body.asString(), "/owner/package/main/js/a")
        }

        // test path a/b
        try await app.test(.GET, "/owner/package/~/js/a/b") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "application/javascript")
            XCTAssertEqual(res.body.asString(), "/owner/package/main/js/a/b")
        }
    }

    func test_documentation_ref_js() throws {
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

    func test_documentation_current_data() async throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: uri.path))
        }
        let pkg = try await savePackageAsync(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          reference: .branch("main"))
            .save(on: app.db)

        // MUT
        // test base url
        try await app.test(.GET, "/owner/package/~/data/a") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual(res.body.asString(), "/owner/package/main/data/a")
        }

        // test path a/b
        try await app.test(.GET, "/owner/package/~/data/a/b") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual(res.body.asString(), "/owner/package/main/data/a/b")
        }

        // test case-insensitivity
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2168
        try await app.test(.GET, "/owner/package/~/data/documentation/Foo.json") { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "application/octet-stream")
            XCTAssertEqual(res.body.asString(),
                           "/owner/package/main/data/documentation/foo.json")
        }
    }

    func test_documentation_ref_data() throws {
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

    func test_documentation_canonicalCapitalisation() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok, body: .init(string: uri.path))
        }
        
        // The `packageName` property on the `Version` has been set to the lower-cased version so
        // we can be sure the canonical URL is built from the properties on the `Repository` model.
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, name: "Package", owner: "Owner")
            .save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "0123456789",
                    commitDate: .t0,
                    docArchives: [.init(name: "docs", title: "Docs")],
                    latest: .defaultBranch,
                    packageName: "package",
                    reference: .tag(1, 2, 3))
            .save(on: app.db).wait()

        try app.test(.GET, "/owner/package/1.2.3/documentation/a/b") { response in
            let document = try SwiftSoup.parse(response.body.string)
            let linkElements = try document.select("link[rel='canonical']")
            XCTAssertEqual(linkElements.count, 1)

            let href = try linkElements.first()!.attr("href")
            XCTAssertEqual(href, "/Owner/Package/1.2.3/documentation/a/b")
        }
    }

    func test_documentation_issue_2287() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2287
        // Ensure references are path encoded
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("feature/1.2.3"))
        .save(on: app.db)
        Current.fetchDocumentation = { _, _ in .init(status: .ok, body: .mockIndexHTML()) }

        // MUT

        // test default path
        try await app.test(.GET, "/owner/package/~/documentation/target") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "current-index")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/~/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
            XCTAssertFalse(body.contains(#"<link rel="canonical""#))
            XCTAssert(body.contains(#"Documentation for <span class="branch">feature/1.2.3</span>"#))
            XCTAssert(body.contains(#"<li class="current"><a href="/owner/package/feature-1.2.3/documentation/target"><span class="branch">feature/1.2.3</span></a></li>"#))
        }

        // test reference root path
        try await app.test(.GET, "/owner/package/feature-1.2.3/documentation/target") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "ref-index")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/feature-1.2.3/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/feature-1.2.3/favicon.ico" />"#))
            XCTAssert(body.contains(#"<link rel="canonical" href="/owner/package/feature/1.2.3/documentation/target" />"#))
            XCTAssert(body.contains(#"Documentation for <span class="branch">feature-1.2.3</span>"#))
        }

        // test path a/b
        try await app.test(.GET, "/owner/package/feature-1.2.3/documentation/a/b") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.content.contentType?.description, "text/html; charset=utf-8")
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "ref-index-path")
            // Call out a couple of specific snippets in the html
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/feature-1.2.3/""#))
            XCTAssert(body.contains(#"<link rel="icon" href="/owner/package/feature-1.2.3/favicon.ico" />"#))
            XCTAssert(body.contains(#"<link rel="canonical" href="/owner/package/feature/1.2.3/documentation/a/b" />"#))
            XCTAssert(body.contains(#"Documentation for <span class="branch">feature-1.2.3</span>"#))
        }
    }

    func test_documentation_routes_tutorials() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try await Repository(package: pkg, name: "package", owner: "owner")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "docs", title: "Docs")],
                          latest: .defaultBranch,
                          packageName: "pkg",
                          reference: .branch("main"))
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "9876543210",
                          commitDate: .t0,
                          docArchives: [.init(name: "docs", title: "Docs")],
                          latest: .release,
                          packageName: "pkg",
                          reference: .tag(1, 0, 0))
            .save(on: app.db)
        Current.fetchDocumentation = { _, _ in .init(status: .ok, body: .mockIndexHTML()) }

        // MUT
        try await app.test(.GET, "/owner/package/~/tutorials") { res async in
            XCTAssertEqual(res.status, .notFound)
        }
        try await app.test(.GET, "/owner/package/~/tutorials/foo") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index")
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/~/""#))
        }
        try await app.test(.GET, "/owner/package/~/tutorials/foo#anchor") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            let body = String(buffer: res.body)
            assertSnapshot(of: body, as: .html, named: "index")
            XCTAssert(body.contains(#"var baseUrl = "/owner/package/~/""#))
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
                  headers: ["content-type": "application/json"],
                  body: .init(string: uri.path))
        }

        // MUT
        try app.test(.GET, "/owner/package/1.2.3/theme-settings.json") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/json")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/theme-settings.json")
        }
    }

    func test_linkablePaths() throws {
        // setup
        Current.fetchDocumentation = { _, uri in
            // embed uri.path in the body as a simple way to test the requested url
            .init(status: .ok,
                  headers: ["content-type": "application/json"],
                  body: .init(string: uri.path))
        }

        // MUT
        try app.test(.GET, "/owner/package/1.2.3/linkable-paths.json") {
            XCTAssertEqual($0.status, .ok)
            XCTAssertEqual($0.content.contentType?.description, "application/json")
            XCTAssertEqual($0.body.asString(), "/owner/package/1.2.3/linkable-paths.json")
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
            XCTAssertTrue($0.body.asString().contains(#"<link rel="stylesheet" href="/docc.css?test" />"#),
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

    func test_siteMap_prod() async throws {
        // Ensure sitemap routing is configured in prod
        // Setup
        Current.environment = { .production }
        // We also need to set up a new app that's configured for production,
        // because app.test is not affected by Current overrides.
        let prodApp = try await setup(.production)

        do {
            // setup
            let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
            try await package.save(on: app.db)
            try await Repository(package: package, defaultBranch: "default",
                                 lastCommitDate: Current.date(),
                                 name: "Repo0", owner: "Owner").save(on: app.db)
            try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                              reference: .branch("default")).save(on: app.db)

            // MUT
            try await prodApp.test(.GET, "/owner/repo0/sitemap.xml") { res async in
                XCTAssertEqual(res.status, .ok)
            }
        } catch {
            try? await prodApp.asyncShutdown()
            throw error
        }
        try await prodApp.asyncShutdown()
    }

    func test_siteMap_dev() async throws {
        // Ensure we don't serve sitemaps in dev
        // app and Current.environment are configured for .development by default

        // setup
        let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
        try await package.save(on: app.db)
        try await Repository(package: package, defaultBranch: "default",
                             lastCommitDate: Current.date(),
                             name: "Repo0", owner: "Owner").save(on: app.db)
        try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                          reference: .branch("default")).save(on: app.db)

        // MUT
        try await app.test(.GET, "/owner/repo0/sitemap.xml") { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func test_issue_2288() async throws {
        // Ensures default branch updates don't introduce a "documentation gap"
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2288

        // setup
        let pkg = try savePackage(on: app.db, "https://github.com/foo/bar".url, processingStage: .ingestion)
        try await Repository(package: pkg, defaultBranch: "main", name: "bar", owner: "foo")
            .save(on: app.db)
        try await Version(package: pkg,
                          commit: "0123456789",
                          commitDate: .t0,
                          docArchives: [.init(name: "target", title: "Target")],
                          latest: .defaultBranch,
                          packageName: "bar",
                          reference: .branch("main"))
            .save(on: app.db)
        Current.fileManager.fileExists = { @Sendable path in
            if path.hasSuffix("Package.resolved") { return false }
            return true
        }
        Current.git = .init(
            commitCount: { _ in 2 },
            firstCommitDate: { _ in .t0 },
            lastCommitDate: { _ in .t1 },
            getTags: { _ in [] },
            hasBranch: { _, _ in true },
            revisionInfo: { ref, _ in
                if ref == .branch("main") { return .init(commit: "new-commit", date: .t1) }
                fatalError("revisionInfo: \(ref)")
            },
            shortlog: { _ in "2\tauthor" }
        )
        Current.shell.run = { @Sendable cmd, _ in
            if cmd.description == "swift package dump-package" { return .mockManifest }
            return ""
        }
        // Make sure the new commit doesn't get throttled
        Current.date = { .t1 + Constants.branchVersionRefreshDelay + 1 }
        Current.fetchDocumentation = { _, _ in .init(status: .ok, body: .mockIndexHTML()) }

        // Ensure documentation is resolved
        try await app.test(.GET, "/foo/bar/~/documentation/target") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            assertSnapshot(of: String(buffer: res.body), as: .html, named: "index")
        }

        // Run analyze to detect a new default branch version
        try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(1))

        // Confirm that analysis has picked up the new version
        let commit = try await Version.query(on: app.db).all().map(\.commit)
        XCTAssertEqual(commit, ["new-commit"])

        // Ensure documentation is still being resolved
        try await app.test(.GET, "/foo/bar/~/documentation/target") { @MainActor res in
            await Task.yield() // essential to avoid deadlocking
            XCTAssertEqual(res.status, .ok)
            assertSnapshot(of: String(buffer: res.body), as: .html, named: "index")
        }
    }

    func test_getDocRoute_documentation() async throws {
        // owner/repo/1.2.3/documentation/archive
        let req = Request(application: app, url: "", on: app.eventLoopGroup.next())
        req.parameters.set("owner", to: "owner")
        req.parameters.set("repository", to: "repo")
        req.parameters.set("reference", to: "1.2.3")
        req.parameters.set("archive", to: "archive")

        let route = try await req.getDocRoute(fragment: .documentation)
        XCTAssertEqual(route, .init(owner: "owner", repository: "repo", docVersion: .reference("1.2.3"), fragment: .documentation, pathElements: ["archive"]))
    }

    func test_getDocRoute_documentation_current() async throws {
        nonisolated(unsafe) let cache = CurrentReferenceCache()
        Current.currentReferenceCache = { cache }
        // owner/repo/~/documentation/archive
        let req = Request(application: app, url: "", on: app.eventLoopGroup.next())
        req.parameters.set("owner", to: "owner")
        req.parameters.set("repository", to: "repo")
        req.parameters.set("reference", to: "~")
        req.parameters.set("archive", to: "archive")

        do { // No cache value available and we've not set up the db with a record to be found -> notFound must be raised
            _ = try await req.getDocRoute(fragment: .documentation)
            XCTFail("expected a .notFound error")
        } catch let error as Abort where error.status == .notFound {
            // expected error
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        cache[owner: "owner", repository: "repo"] = "1.2.3"

        do { // Now with the cache in place this resolves
            let route = try await req.getDocRoute(fragment: .documentation)
            XCTAssertEqual(route, .init(owner: "owner", repository: "repo", docVersion: .current(referencing: "1.2.3"), fragment: .documentation, pathElements: ["archive"]))
        }
    }

    func test_getDocRoute_missing_reference() async throws {
        do {
            let req = Request(application: app, on: app.eventLoopGroup.next())
            req.parameters.set("owner", to: "owner")
            req.parameters.set("repository", to: "repo")
            _ = try await req.getDocRoute(fragment: .documentation)
            XCTFail("expected a .badRequest error")
        } catch let error as Abort where error.status == .badRequest {
            // expected error
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_getDocRoute_missing_archive() async throws {
        do { // reference but no archive
            do {
                let req = Request(application: app, on: app.eventLoopGroup.next())
                req.parameters.set("owner", to: "owner")
                req.parameters.set("repository", to: "repo")
                req.parameters.set("reference", to: "1.2.3")
                _ = try await req.getDocRoute(fragment: .documentation)
                XCTFail("expected a .badRequest error")
            } catch let error as Abort where error.status == .badRequest {
                // expected error
            } catch {
                XCTFail("unexpected error: \(error)")
            }
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

private extension ByteBuffer {
    static func mockIndexHTML(baseURL: String = "/") -> Self {
        let baseURL = baseURL.hasSuffix("/") ? baseURL : baseURL + "/"
        return .init(string: """
            <!doctype html>
            <html lang="en-US">

            <head>
                <meta charset="utf-8">
                <meta http-equiv="X-UA-Compatible" content="IE=edge">
                <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
                <link rel="icon" href="\(baseURL)favicon.ico">
                <link rel="mask-icon" href="\(baseURL)favicon.svg" color="#333333">
                <title>Documentation</title>
                <script>
                    var baseUrl = "\(baseURL)"
                </script>
                <script defer="defer" src="\(baseURL)js/chunk-vendors.bdb7cbba.js"></script>
                <script defer="defer" src="\(baseURL)js/index.2871ffbd.js"></script>
                <link href="\(baseURL)css/index.ff036a9e.css" rel="stylesheet">
            </head>

            <body data-color-scheme="auto"><noscript>[object Module]</noscript>
                <div id="app"></div>
            </body>

            </html>
            """)
    }
}
