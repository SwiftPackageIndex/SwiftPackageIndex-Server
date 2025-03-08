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
import SnapshotTesting
import SwiftSoup
import Testing
import Vapor


extension AllTests.PackageController_routesTests {

    @Test func show() async throws {
        try await withDependencies {
            $0.date.now = .t0
            $0.environment.dbId = { nil }
            $0.environment.processingBuildBacklog = { false }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner")
                    .save(on: app.db)
                try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)

                // MUT
                try await app.test(.GET, "/owner/package") { res async in
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func show_checkingGitHubRepository_notFound() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
            $0.httpClient.fetchHTTPStatusCode = { @Sendable _ in .notFound }
        } operation: {
            try await withApp { app in
                // MUT
                try await app.test(.GET, "/unknown/package") { res async in
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func show_checkingGitHubRepository_found() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
            $0.httpClient.fetchHTTPStatusCode = { @Sendable _ in .ok }
        } operation: {
            try await withApp { app in
            // MUT
                try await app.test(.GET, "/unknown/package") { res async in
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func show_checkingGitHubRepository_error() async throws {
        // Make sure we don't throw an internal server error in case
        // fetchHTTPStatusCode fails
        try await withDependencies {
            $0.environment.dbId = { nil }
            $0.httpClient.fetchHTTPStatusCode = { @Sendable _ in throw FetchError() }
        } operation: {
            try await withApp { app in
            // MUT
                try await app.test(.GET, "/unknown/package") { res async in
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func ShowModel_packageAvailable() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
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
                    Issue.record("expected package to be available")
            }
        }
    }

    @Test func ShowModel_packageMissing() async throws {
        try await withDependencies {
            $0.httpClient.fetchHTTPStatusCode = { @Sendable _ in .ok }
        } operation: {
            try await withApp { app in
                // MUT
                let model = try await PackageController.ShowModel(db: app.db, owner: "owner", repository: "package")

                // validate
                switch model {
                    case .packageAvailable, .packageDoesNotExist:
                        Issue.record("expected package to be missing")
                    case .packageMissing:
                        break
                }
            }
        }
    }

    @Test func ShowModel_packageDoesNotExist() async throws {
        try await withDependencies {
            $0.httpClient.fetchHTTPStatusCode = { @Sendable _ in .notFound }
        } operation: {
            try await withApp { app in
                // MUT
                let model = try await PackageController.ShowModel(db: app.db, owner: "owner", repository: "package")

                // validate
                switch model {
                    case .packageAvailable, .packageMissing:
                        Issue.record("expected package not to exist")
                    case .packageDoesNotExist:
                        break
                }
            }
        }
    }

    @Test func ShowModel_fetchHTTPStatusCode_error() async throws {
        try await withDependencies {
            $0.httpClient.fetchHTTPStatusCode = { @Sendable _ in throw FetchError() }
        } operation: {
            try await withApp { app in
                // MUT
                let model = try await PackageController.ShowModel(db: app.db, owner: "owner", repository: "package")

                // validate
                switch model {
                    case .packageAvailable, .packageMissing:
                        Issue.record("expected package not to exist")
                    case .packageDoesNotExist:
                        break
                }
            }
        }
    }

    @Test func readme_route() async throws {
        // Test that readme route is set up
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            try await Repository(package: pkg, name: "package", owner: "owner")
                .save(on: app.db)
            try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)

            // MUT
            try await app.test(.GET, "/owner/package/readme") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test func readme_basic() async throws {
        // Test readme fragment happy path
        try await withDependencies {
            $0.s3.fetchReadme = { @Sendable _, _ in
                #"<div id="readme"><article>readme content</article></div>"#
            }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, defaultBranch: "main", name: "package", owner: "owner", readmeHtmlUrl: "html url")
                    .save(on: app.db)
                try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)
                let req = Request(application: app, on: app.eventLoopGroup.next())
                req.parameters.set("owner", to: "owner")
                req.parameters.set("repository", to: "package")

                // MUT
                let node = try await PackageController.readme(req: req)

                // validate
                #expect(node.render(indentedBy: .spaces(2)) == """
            <turbo-frame id="readme_content">readme content</turbo-frame>
            """)
            }
        }
    }

    @Test func readme_no_readmeHtmlUrl() async throws {
        // Test readme fragment when there's no readme html url
        try await withDependencies {
            $0.s3.fetchReadme = { @Sendable _, _ in
                Issue.record("must not be called")
                return ""
            }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner", readmeHtmlUrl: nil)
                    .save(on: app.db)
                try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)
                let req = Request(application: app, on: app.eventLoopGroup.next())
                req.parameters.set("owner", to: "owner")
                req.parameters.set("repository", to: "package")

                // MUT
                let node = try await PackageController.readme(req: req)

                // validate
                #expect(node.render(indentedBy: .spaces(2)) == """
            <turbo-frame id="readme_content">
              <p>This package does not have a README file.</p>
            </turbo-frame>
            """)
            }
        }
    }

    @Test func readme_error() async throws {
        // Test readme fragment when fetchS3Readme throws
        try await withDependencies {
            $0.s3.fetchReadme = { @Sendable _, _ in
                struct Error: Swift.Error { }
                throw Error()
            }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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
                #expect(node.render(indentedBy: .spaces(2)) == """
            <turbo-frame id="readme_content">
              <p>This package's README file couldn't be loaded. Try 
                <a href="html url">viewing it on GitHub</a>.
              </p>
            </turbo-frame>
            """)
                #expect(try await Repository.query(on: app.db).count() == 1)
                let s3Readme = try #require(try await Repository.query(on: app.db).first()?.s3Readme)
                #expect(s3Readme.isError)
            }
        }
    }

    @Test func releases() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            try await Repository(package: pkg, name: "package", owner: "owner")
                .save(on: app.db)
            try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)

            // MUT
            try await app.test(.GET, "/owner/package/releases") { res async in
                #expect(res.status == .ok)
            }
        }
    }

    @Test func builds() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner")
                    .save(on: app.db)
                try await Version(package: pkg, latest: .defaultBranch).save(on: app.db)

                // MUT
                try await app.test(.GET, "/owner/package/builds") { res async in
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func maintainerInfo() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner")
                    .save(on: app.db)
                try await Version(package: pkg, latest: .defaultBranch, packageName: "pkg")
                    .save(on: app.db)

                // MUT
                try await app.test(.GET, "/owner/package/information-for-package-maintainers") { res async in
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func maintainerInfo_no_packageName() async throws {
        // Ensure we display the page even if packageName is not set
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner")
                    .save(on: app.db)
                try await Version(package: pkg, latest: .defaultBranch, packageName: nil)
                    .save(on: app.db)

                // MUT
                try await app.test(.GET, "/owner/package/information-for-package-maintainers") { res async in
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func DocRoute_baseURL() throws {
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .documentation).baseURL == "foo/bar/1.2.3"
        )
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .css).baseURL == "foo/bar/1.2.3"
        )
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("main"), fragment: .documentation).baseURL == "foo/bar/main"
        )
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("Main"), fragment: .documentation).baseURL == "foo/bar/main"
        )
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .reference("feature/a"), fragment: .documentation).baseURL == "foo/bar/feature-a"
        )
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "1.2.3"), fragment: .documentation).baseURL == "foo/bar/1.2.3"
        )
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "1.2.3"), fragment: .documentation).baseURL == "foo/bar/1.2.3"
        )
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "main"), fragment: .documentation).baseURL == "foo/bar/main"
        )
        #expect(
            DocRoute(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "Main"), fragment: .documentation).baseURL == "foo/bar/main"
        )
    }

    @Test func awsDocumentationURL() throws {
        try withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
        } operation: { () throws in
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("Main"), fragment: .documentation, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/main/documentation/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .css, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/css/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .documentation, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/documentation/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .data, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/data/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .images, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/images/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .img, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/img/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .svgImages, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/images/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .svgImg, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/img/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .js, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/js/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .linkablePaths, pathElements: [""])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/linkable-paths.json"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .linkablePaths, pathElements: ["ignored"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/linkable-paths.json"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .themeSettings, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/path/theme-settings.json"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("1.2.3"), fragment: .themeSettings, pathElements: [""])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/theme-settings.json"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .reference("feature/a"), fragment: .documentation, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/feature-a/documentation/path"
            )
        }
    }

    @Test func awsDocumentationURL_current() throws {
        try withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
        } operation: { () throws in
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "Main"), fragment: .documentation, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/main/documentation/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "1.2.3"), fragment: .documentation, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/1.2.3/documentation/path"
            )
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "Foo", repository: "Bar", docVersion: .current(referencing: "feature/a"), fragment: .documentation, pathElements: ["path"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/foo/bar/feature-a/documentation/path"
            )
        }
    }

    @Test func awsDocumentationURL_issue2287() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2287
        // reference with / needs to be escaped
        try withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
        } operation: { () throws in
            #expect(
                try PackageController.awsDocumentationURL(route: .init(owner: "linhay", repository: "SectionKit", docVersion: .reference("feature/2.0.0"), fragment: .documentation, pathElements: ["sectionui"])).string == "http://docs-bucket.s3-website.us-east-2.amazonaws.com/linhay/sectionkit/feature-2.0.0/documentation/sectionui"
            )
        }
    }

    @Test func canonicalDocumentationUrl() throws {
        // There is no canonical URL for external or universal cases of the canonical target.
        #expect(PackageController.canonicalDocumentationUrl(from: "", owner: "", repository: "", docVersion: .reference(""),
                                                                 toTarget: .external(url: "https://example.com")) == nil)

        #expect(PackageController.canonicalDocumentationUrl(from: "", owner: "", repository: "", docVersion: .reference(""),
                                                                 toTarget: .internal(docVersion: .reference(""), archive: "")) == nil)

        // There should be no canonical URL if the package owner/repo/ref prefix doesn't match even with a valid canonical target.
        #expect(PackageController.canonicalDocumentationUrl(from: "/some/random/url/without/matching/prefix",
                                                                 owner: "owner",
                                                                 repository: "repo",
                                                                 docVersion: .reference("non-canonical-ref"),
                                                                 toTarget: .internal(docVersion: .reference("canonical-ref"), archive: "archive")) == nil)

        // Switching a non-canonical reference for a canonical one at the root of the documentation
        #expect(PackageController.canonicalDocumentationUrl(from: "/owner/repo/non-canonical-ref/documentation/archive",
                                                                   owner: "owner",
                                                                   repository: "repo",
                                                                   docVersion: .reference("non-canonical-ref"),
                                                                   toTarget: .internal(docVersion: .reference("canonical-ref"), archive: "archive")) == "/owner/repo/canonical-ref/documentation/archive")

        #expect(PackageController.canonicalDocumentationUrl(from: "/owner/repo/non-canonical-ref/documentation/archive/symbol:$-%",
                                                                   owner: "owner",
                                                                   repository: "repo",
                                                                   docVersion: .reference("non-canonical-ref"),
                                                                   toTarget: .internal(docVersion: .reference("canonical-ref"), archive: "archive")) == "/owner/repo/canonical-ref/documentation/archive/symbol:$-%")
    }

    @Test func documentation_routes_contentType() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok }
        } operation: {
            try await withApp { app in
                try await app.test(.GET, "/owner/package/main/images/foo/bar.jpeg") { res async in
                    #expect(res.headers.contentType == .init(type: "application", subType: "octet-stream"))
                }
                try await app.test(.GET, "/owner/package/main/images/foo/bar.svg") { res async in
                    #expect(res.headers.contentType == .init(type: "image", subType: "svg+xml"))
                }
                try await app.test(.GET, "/owner/package/main/images/foo/bar.SVG") { res async in
                    #expect(res.headers.contentType == .init(type: "image", subType: "svg+xml"))
                }
                try await app.test(.GET, "/owner/package/main/img/foo/bar.jpeg") { res async in
                    #expect(res.headers.contentType == .init(type: "application", subType: "octet-stream"))
                }
                try await app.test(.GET, "/owner/package/main/img/foo/bar.svg") { res async in
                    #expect(res.headers.contentType == .init(type: "image", subType: "svg+xml"))
                }
                try await app.test(.GET, "/owner/package/main/img/foo/bar.SVG") { res async in
                    #expect(res.headers.contentType == .init(type: "image", subType: "svg+xml"))
                }
            }
        }
    }

    @Test func documentation_routes_redirect() async throws {
        // Test the redirect documentation routes without any reference:
        //   /owner/package/documentation + various path elements
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
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
                #expect(res.status == .seeOther)
                #expect(res.headers.location == "/owner/package/1.0.0/documentation/target")
            }
            try await app.test(.GET, "/owner/package/documentation/target/symbol") { res async in
                #expect(res.status == .seeOther)
                #expect(res.headers.location == "/owner/package/1.0.0/documentation/target/symbol")
            }
            // We do not validate the catchall - authors need to make sure they point
            // the path after `documentation/` at a valid doc path. We do not try and map it to
            // generated docs (i.e. `target` in this test) as that would prevent them from
            // cross-target linking.
            // Effectively, all we're doing is inserting the correct `ref` before `documentation`.
            try await app.test(.GET, "/owner/package/documentation/foo") { res async in
                #expect(res.status == .seeOther)
                #expect(res.headers.location == "/owner/package/1.0.0/documentation/foo")
            }
            try await app.test(.GET, "/owner/package/documentation/foo#anchor") { res async in
                #expect(res.status == .seeOther)
                #expect(res.headers.location == "/owner/package/1.0.0/documentation/foo#anchor")
            }
            try await app.test(.GET, "/owner/package/documentation/FOO") { res async in
                #expect(res.status == .seeOther)
                #expect(res.headers.location == "/owner/package/1.0.0/documentation/foo")
            }
            try await app.test(.GET, "/owner/package/tutorials/foo") { res async in
                #expect(res.status == .seeOther)
                #expect(res.headers.location == "/owner/package/1.0.0/tutorials/foo")
            }
        }
    }

    @Test func documentation_routes_current() async throws {
        // Test the current (~) documentation routes:
        //   /owner/package/documentation/~ + various path elements
        try await withDependencies {
            $0.currentReferenceCache = .disabled
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok(body: .mockIndexHTML()) }
            $0.timeZone = .utc
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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

                // test partially qualified route (no archive)
                try await app.test(.GET, "/owner/package/~/documentation") { @Sendable res async in
                    #expect(res.status == .seeOther)
                    #expect(res.headers.location == "/owner/package/1.0.0/documentation/target")
                }

                // test fully qualified route
                try await app.test(.GET, "/owner/package/~/documentation/target") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/~/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
                    #expect(!body.contains(#"<link rel="canonical""#))
                    #expect(body.contains(#"<span class="stable">1.0.0</span>"#))
                }

                // test catchall
                try await app.test(.GET, "/owner/package/~/documentation/target/a/b#anchor") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/~/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
                    #expect(!body.contains(#"<link rel="canonical""#))
                    #expect(!body.contains(#"a/b#anchor"#))
                    #expect(body.contains(#"<span class="stable">1.0.0</span>"#))
                }

                // Test case insensitive path.
                try await app.test(.GET, "/Owner/Package/~/documentation/target/A/b#anchor") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index-mixed-case")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/~/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
                    #expect(!body.contains(#"<link rel="canonical""#))
                    #expect(!body.contains(#"a/b#anchor"#))
                    #expect(body.contains(#"<span class="stable">1.0.0</span>"#))
                }
            }
        }
    }

    @Test func documentation_routes_current_rewrite() async throws {
        // Test the current (~) documentation routes with baseURL rewriting:
        //   /owner/package/documentation/~ + various path elements
        try await withDependencies {
            $0.currentReferenceCache = .disabled
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok(body: .mockIndexHTML(baseURL: "/owner/package/1.0.0")) }
            $0.timeZone = .utc
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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

                // test fully qualified route
                try await app.test(.GET, "/owner/package/~/documentation/target") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/~/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
                    #expect(!body.contains(#"<link rel="canonical""#))
                    #expect(body.contains(#"<span class="stable">1.0.0</span>"#))
                }

                // test catchall
                try await app.test(.GET, "/owner/package/~/documentation/target/a/b#anchor") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
                    #expect(!body.contains(#"<link rel="canonical""#))
                    #expect(!body.contains(#"a/b#anchor"#))
                    #expect(body.contains(#"<span class="stable">1.0.0</span>"#))
                }

                // Test case insensitive path.
                try await app.test(.GET, "/Owner/Package/~/documentation/target/A/b#anchor") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index-mixed-case")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
                    #expect(!body.contains(#"<link rel="canonical""#))
                    #expect(!body.contains(#"a/b#anchor"#))
                    #expect(body.contains(#"<span class="stable">1.0.0</span>"#))
                }
            }
        }
    }

    @Test func documentation_routes_ref() async throws {
        // Test the documentation routes with a reference:
        //   /owner/package/documentation/{reference} + various path elements
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok(body: .mockIndexHTML()) }
            $0.timeZone = .utc
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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

                // MUT

                // test partially qualified route (no archive)
                try await app.test(.GET, "/owner/package/1.2.3/documentation") { @Sendable res async in
                    #expect(res.status == .seeOther)
                    #expect(res.headers.location == "/owner/package/1.2.3/documentation/target")
                }

                // test fully qualified route
                try await app.test(.GET, "/owner/package/1.2.3/documentation/target") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index-target")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/1.2.3/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/1.2.3/favicon.ico" />"#))
                    #expect(body.contains(#"<link rel="canonical" href="/owner/package/1.2.3/documentation/target" />"#))
                    #expect(body.contains(#"<span class="stable">1.2.3</span>"#))
                }

                // test catchall
                try await app.test(.GET, "/owner/package/1.2.3/documentation/target/a/b#anchor") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index-target-a-b")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/1.2.3/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/1.2.3/favicon.ico" />"#))
                    #expect(body.contains(#"<link rel="canonical" href="/owner/package/1.2.3/documentation/target/a/b#anchor" />"#))
                    #expect(body.contains(#"<span class="stable">1.2.3</span>"#))
                }

                // Test case insensitive path.
                try await app.test(.GET, "/Owner/Package/1.2.3/documentation/target/A/b#Anchor") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index-target-a-b-mixed-case")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/1.2.3/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/1.2.3/favicon.ico" />"#))
                    #expect(body.contains(#"<link rel="canonical" href="/owner/package/1.2.3/documentation/target/A/b#Anchor" />"#))
                    #expect(body.contains(#"<span class="stable">1.2.3</span>"#))
                }
            }
        }
    }

    @Test func documentation_routes_no_archive() async throws {
        // Test documentation routes when no archive is in the path
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok(body: .mockIndexHTML()) }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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
                try await app.test(.GET, "/owner/package/main/documentation") { res async in
                    #expect(res.status == .seeOther)
                    #expect(res.headers.location == "/owner/package/main/documentation/target")
                }
                try await app.test(.GET, "/owner/package/1.0.0/documentation") { res async in
                    #expect(res.status == .seeOther)
                    #expect(res.headers.location == "/owner/package/1.0.0/documentation/target")
                }
                try await app.test(.GET, "/owner/package/~/documentation") { res async in
                    #expect(res.status == .seeOther)
                    #expect(res.headers.location == "/owner/package/1.0.0/documentation/target")
                }
            }
        }
    }

    @Test func documentationRoot_notFound() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .notFound }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner")
                    .save(on: app.db)
                try await Version(package: pkg,
                                  commit: "0123456789",
                                  commitDate: .t0,
                                  docArchives: [], // No docArchives!
                                  latest: .defaultBranch,
                                  packageName: "pkg",
                                  reference: .branch("main"))
                .save(on: app.db)
                try await Version(package: pkg,
                                  commit: "9876543210",
                                  commitDate: .t0,
                                  docArchives: [], // No docArchives!
                                  latest: .release,
                                  packageName: "pkg",
                                  reference: .tag(1, 0, 0))
                .save(on: app.db)

                // MUT
                try await app.test(.GET, "/owner/package/main/documentation") { res async in
                    #expect(res.status == .notFound)
                }
                try await app.test(.GET, "/owner/package/1.0.0/documentation") { res async in
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func documentation_404() async throws {
        // Test conversion of any doc fetching errors into 404s.
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.environment.dbId = { nil }
            $0.httpClient.fetchDocumentation = { @Sendable uri in .badRequest }
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner")
                    .save(on: app.db)
                try await Version(package: pkg, latest: .defaultBranch, packageName: "pkg")
                    .save(on: app.db)

                // MUT
                // test base url
                try await app.test(.GET, "/owner/package/1.2.3/documentation") { res async in
                    #expect(res.status == .notFound)
                }

                // test path a/b
                try await app.test(.GET, "/owner/package/1.2.3/documentation/a/b") { res async in
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func documentation_error() async throws {
        // Test behaviour when fetchDocumentation throws
        struct SomeError: Error { }
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.environment.dbId = { nil }
            $0.httpClient.fetchDocumentation = { @Sendable _ in throw SomeError() }
        } operation: {
            try await withApp { app in
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner")
                    .save(on: app.db)
                try await Version(package: pkg,
                                  commit: "123",
                                  commitDate: .t0,
                                  docArchives: [.init(name: "foo", title: "Foo")],
                                  latest: .defaultBranch,
                                  packageName: "pkg",
                                  reference: .tag(1, 2, 3))
                .save(on: app.db)

                // MUT
                try await app.test(.GET, "/owner/package/1.2.3/documentation") { res async in
                    #expect(res.status == .seeOther)
                    #expect(res.headers.location == "/owner/package/1.2.3/documentation/foo")
                }
                try await app.test(.GET, "/owner/package/1.2.3/documentation/foo") { res async in
                    // hits Current.fetchDocumentation which throws, converted to notFound
                    // Regression test for https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2015
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func documentation_current_css() async throws {
        try await withDependencies {
            $0.currentReferenceCache = .disabled
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/css")
                    #expect(res.body.asString() == "/owner/package/main/css/a")
                }

                // test path a/b
                try await app.test(.GET, "/owner/package/~/css/a/b") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/css")
                    #expect(res.body.asString() == "/owner/package/main/css/a/b")
                }
            }
        }
    }

    @Test func documentation_ref_css() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
        } operation: {
            try await withApp { app in
                // MUT
                // test base url
                try await app.test(.GET, "/owner/package/1.2.3/css/a") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/css")
                    #expect(res.body.asString() == "/owner/package/1.2.3/css/a")
                }

                // test path a/b
                try await app.test(.GET, "/owner/package/1.2.3/css/a/b") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/css")
                    #expect(res.body.asString() == "/owner/package/1.2.3/css/a/b")
                }
            }
        }
    }

    @Test func documentation_current_js() async throws {
        try await withDependencies {
            $0.currentReferenceCache = .disabled
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/javascript")
                    #expect(res.body.asString() == "/owner/package/main/js/a")
                }

                // test path a/b
                try await app.test(.GET, "/owner/package/~/js/a/b") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/javascript")
                    #expect(res.body.asString() == "/owner/package/main/js/a/b")
                }
            }
        }
    }

    @Test func documentation_ref_js() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
        } operation: {
            try await withApp { app in
                // MUT
                // test base url
                try await app.test(.GET, "/owner/package/1.2.3/js/a") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/javascript")
                    #expect(res.body.asString() == "/owner/package/1.2.3/js/a")
                }

                // test path a/b
                try await app.test(.GET, "/owner/package/1.2.3/js/a/b") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/javascript")
                    #expect(res.body.asString() == "/owner/package/1.2.3/js/a/b")
                }
            }
        }
    }

    @Test func documentation_current_data() async throws {
        try await withDependencies {
            $0.currentReferenceCache = .disabled
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/owner/package/main/data/a")
                }

                // test path a/b
                try await app.test(.GET, "/owner/package/~/data/a/b") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/owner/package/main/data/a/b")
                }

                // test case-insensitivity
                // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2168
                try await app.test(.GET, "/owner/package/~/data/documentation/Foo.json") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/owner/package/main/data/documentation/foo.json")
                }
            }
        }
    }

    @Test func documentation_ref_data() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
        } operation: {
            try await withApp { app in
                // MUT
                // test base url
                try await app.test(.GET, "/owner/package/1.2.3/data/a") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/owner/package/1.2.3/data/a")
                }

                // test path a/b
                try await app.test(.GET, "/owner/package/1.2.3/data/a/b") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/owner/package/1.2.3/data/a/b")
                }

                // test case-insensitivity
                // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2168
                try await app.test(.GET, "/apple/swift-nio/main/data/documentation/NIOCore.json") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/apple/swift-nio/main/data/documentation/niocore.json")
                }
            }
        }
    }

    @Test func documentation_canonicalCapitalisation() async throws {
        // The `packageName` property on the `Version` has been set to the lower-cased version so
        // we can be sure the canonical URL is built from the properties on the `Repository` model.
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient.echoURL()
            $0.timeZone = .utc
        } operation: {
            try await withApp { app in
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "Package", owner: "Owner")
                    .save(on: app.db)
                try await Version(package: pkg,
                                  commit: "0123456789",
                                  commitDate: .t0,
                                  docArchives: [.init(name: "docs", title: "Docs")],
                                  latest: .defaultBranch,
                                  packageName: "package",
                                  reference: .tag(1, 2, 3))
                .save(on: app.db)

                try await app.test(.GET, "/owner/package/1.2.3/documentation/a/b") { res async throws in
                    let document = try SwiftSoup.parse(res.body.string)
                    let linkElements = try document.select("link[rel='canonical']")
                    #expect(linkElements.count == 1)

                    let href = try #require(try linkElements.first()?.attr("href"))
                    #expect(href == "/Owner/Package/1.2.3/documentation/a/b")
                }
            }
        }
    }

    @Test func documentation_issue_2287() async throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2287
        // Ensure references are path encoded
        try await withDependencies {
            $0.currentReferenceCache = .disabled
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok(body: .mockIndexHTML()) }
            $0.timeZone = .utc
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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

                // MUT

                // test default path
                try await app.test(.GET, "/owner/package/~/documentation/target") { res async in
                    #expect(res.status == .ok)
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "current-index")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/~/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/~/favicon.ico" />"#))
                    #expect(!body.contains(#"<link rel="canonical""#))
                    #expect(body.contains(#"<span class="branch">feature/1.2.3</span>"#))
                    #expect(body.contains(#"<li class="current"><a href="/owner/package/feature-1.2.3/documentation/target"><span class="branch">feature/1.2.3</span></a></li>"#))
                }

                // test reference root path
                try await app.test(.GET, "/owner/package/feature-1.2.3/documentation/target") { res async in
                    #expect(res.status == .ok)
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "ref-index")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/feature-1.2.3/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/feature-1.2.3/favicon.ico" />"#))
                    #expect(body.contains(#"<link rel="canonical" href="/owner/package/feature/1.2.3/documentation/target" />"#))
                    #expect(body.contains(#"<span class="branch">feature-1.2.3</span>"#))
                }

                // test path a/b
                try await app.test(.GET, "/owner/package/feature-1.2.3/documentation/a/b") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "ref-index-path")
                    // Call out a couple of specific snippets in the html
                    #expect(body.contains(#"var baseUrl = "/owner/package/feature-1.2.3/""#))
                    #expect(body.contains(#"<link rel="icon" href="/owner/package/feature-1.2.3/favicon.ico" />"#))
                    #expect(body.contains(#"<link rel="canonical" href="/owner/package/feature/1.2.3/documentation/a/b" />"#))
                    #expect(body.contains(#"<span class="branch">feature-1.2.3</span>"#))
                }
            }
        }
    }

    @Test func documentation_routes_tutorials() async throws {
        try await withDependencies {
            $0.currentReferenceCache = .disabled
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.environment.dbId = { nil }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok(body: .mockIndexHTML()) }
            $0.timeZone = .utc
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
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

                // MUT
                try await app.test(.GET, "/owner/package/~/tutorials") { res async in
                    #expect(res.status == .notFound)
                }
                try await app.test(.GET, "/owner/package/~/tutorials/foo") { res async in
                    #expect(res.status == .ok)
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index")
                    #expect(body.contains(#"var baseUrl = "/owner/package/~/""#))
                }
                try await app.test(.GET, "/owner/package/~/tutorials/foo#anchor") { res async in
                    #expect(res.status == .ok)
                    let body = String(buffer: res.body)
                    assertSnapshot(of: body, as: .html, named: "index")
                    #expect(body.contains(#"var baseUrl = "/owner/package/~/""#))
                }
            }
        }
    }


    @Test func favicon() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient
                .echoURL(headers: ["content-type": "application/octet-stream"])
        } operation: {
            try await withApp { app in
                // MUT
                try await app.test(.GET, "/owner/package/1.2.3/favicon.ico") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/owner/package/1.2.3/favicon.ico")
                }

                try await app.test(.GET, "/owner/package/1.2.3/favicon.svg") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/octet-stream")
                    #expect(res.body.asString() == "/owner/package/1.2.3/favicon.svg")
                }
            }
        }
    }

    @Test func themeSettings() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient
                .echoURL(headers: ["content-type": "application/json"])
        } operation: {
            try await withApp { app in
                // MUT
                try await app.test(.GET, "/owner/package/1.2.3/theme-settings.json") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/json")
                    #expect(res.body.asString() == "/owner/package/1.2.3/theme-settings.json")
                }
            }
        }
    }

    @Test func linkablePaths() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = App.HTTPClient
                .echoURL(headers: ["content-type": "application/json"])
        } operation: {
            try await withApp { app in
            // MUT
                try await app.test(.GET, "/owner/package/1.2.3/linkable-paths.json") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "application/json")
                    #expect(res.body.asString() == "/owner/package/1.2.3/linkable-paths.json")
                }
            }
        }
    }

    @Test func tutorial() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.httpClient.fetchDocumentation = { @Sendable uri in
                // embed uri.path in the body as a simple way to test the requested url
                    .ok(body: "<p>\(uri.path)</p>")
            }
            $0.timeZone = .utc
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                try await Repository(package: pkg, name: "package", owner: "owner")
                    .save(on: app.db)
                try await Version(package: pkg,
                                  commit: "0123456789",
                                  commitDate: Date(timeIntervalSince1970: 0),
                                  docArchives: [.init(name: "docs", title: "Docs")],
                                  latest: .defaultBranch,
                                  packageName: "pkg",
                                  reference: .tag(.init(1, 2, 3)))
                .save(on: app.db)

                // MUT
                // test path a/b
                try await app.test(.GET, "/owner/package/1.2.3/tutorials/a/b") { res async in
                    #expect(res.status == .ok)
                    #expect(res.content.contentType?.description == "text/html; charset=utf-8")
                    #expect(
                        res.body.asString().contains("<p>/owner/package/1.2.3/tutorials/a/b</p>"),
                        "was: \(res.body.asString())"
                    )
                    // Assert body includes the docc.css stylesheet link (as a test that our proxy header injection works)
                    #expect(res.body.asString().contains(#"<link rel="stylesheet" href="/docc.css?test" />"#),
                            "was: \(res.body.asString())")
                }

                // Test case insensitive path.
                try await app.test(.GET, "/Owner/Package/1.2.3/tutorials/a/b") { res async in
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func documentationVersionArray_subscriptByReference() throws {
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
        let versionTwoBeta = try #require(versions[reference: "2.0.0-beta1"])
        let semVer = try #require(versionTwoBeta.reference.semVer)

        #expect(semVer.major == 2)
        #expect(semVer.minor == 0)
        #expect(semVer.patch == 0)
        #expect(semVer.preRelease == "beta1")
        #expect(semVer.build == "")
    }

    @Test func documentationVersionArray_latestMajorVersions() throws {
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
        #expect(latestMajorRerefences == ["1.1.2", "2.1.1", "3.0.0"])
    }

    @Test func siteMap_prod() async throws {
        // Ensure sitemap routing is configured in prod
        try await withDependencies {
            $0.environment.current = { .production }
        } operation: {
            try await withApp(environment: .production) { prodApp in
                // setup
                let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
                try await package.save(on: prodApp.db)
                try await Repository(package: package, defaultBranch: "default",
                                     lastCommitDate: Date.now,
                                     name: "Repo0", owner: "Owner").save(on: prodApp.db)
                try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                                  reference: .branch("default")).save(on: prodApp.db)

                // MUT
                try await prodApp.test(.GET, "/owner/repo0/sitemap.xml") { res async in
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func siteMap_dev() async throws {
        // Ensure we don't serve sitemaps in dev
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp(environment: .development) { devApp in
                // setup
                let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
                try await package.save(on: devApp.db)
                try await Repository(package: package, defaultBranch: "default",
                                     lastCommitDate: Date.now,
                                     name: "Repo0", owner: "Owner").save(on: devApp.db)
                try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                                  reference: .branch("default")).save(on: devApp.db)

                // MUT
                try await devApp.test(.GET, "/owner/repo0/sitemap.xml") { res async in
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func issue_2288() async throws {
        // Ensures default branch updates don't introduce a "documentation gap"
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2288
        try await withDependencies {
            $0.currentReferenceCache = .disabled
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.environment.loadSPIManifest = { _ in nil }
            $0.fileManager.fileExists = { @Sendable path in
                if path.hasSuffix("Package.resolved") { return false }
                return true
            }
            $0.git.commitCount = { @Sendable _ in 2}
            $0.git.firstCommitDate = { @Sendable _ in .t0 }
            $0.git.getTags = { @Sendable _ in [] }
            $0.git.hasBranch = { @Sendable _, _ in true }
            $0.git.lastCommitDate = { @Sendable _ in .t1 }
            $0.git.revisionInfo = { @Sendable ref, _ in
                if ref == .branch("main") { return .init(commit: "new-commit", date: .t1) }
                fatalError("revisionInfo: \(ref)")
            }
            $0.git.shortlog = { @Sendable _ in "2\tauthor" }
            $0.httpClient.fetchDocumentation = { @Sendable _ in .ok(body: .mockIndexHTML()) }
            $0.shell.run = { @Sendable cmd, _ in
                if cmd.description == "swift package dump-package" { return .mockManifest }
                return ""
            }
            $0.timeZone = .utc
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "https://github.com/foo/bar".url, processingStage: .ingestion)
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
                // Make sure the new commit doesn't get throttled
                try await withDependencies {
                    $0.date.now = .t1 + Constants.branchVersionRefreshDelay + 1
                } operation: {
                    // Ensure documentation is resolved
                    try await app.test(.GET, "/foo/bar/~/documentation/target") { res async in
                        #expect(res.status == .ok)
                        assertSnapshot(of: String(buffer: res.body), as: .html, named: "index")
                    }

                    // Run analyze to detect a new default branch version
                    try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(1))

                    // Confirm that analysis has picked up the new version
                    let commit = try await Version.query(on: app.db).all().map(\.commit)
                    #expect(commit == ["new-commit"])

                    // Ensure documentation is still being resolved
                    try await app.test(.GET, "/foo/bar/~/documentation/target") { res async in
                        #expect(res.status == .ok)
                        assertSnapshot(of: String(buffer: res.body), as: .html, named: "index")
                    }
                }
            }
        }
    }

    @Test func getDocRoute_documentation() async throws {
        // owner/repo/1.2.3/documentation/archive
        try await withApp { app in
            let req = Request(application: app, url: "", on: app.eventLoopGroup.next())
            req.parameters.set("owner", to: "owner")
            req.parameters.set("repository", to: "repo")
            req.parameters.set("reference", to: "1.2.3")
            req.parameters.set("archive", to: "archive")

            let route = try await req.getDocRoute(fragment: .documentation)
            #expect(route == .init(owner: "owner", repository: "repo", docVersion: .reference("1.2.3"), fragment: .documentation, pathElements: ["archive"]))
        }
    }

    @Test func getDocRoute_documentation_current() async throws {
        // owner/repo/~/documentation/archive
        try await withDependencies {
            $0.currentReferenceCache = .inMemory
        } operation: {
            try await withApp { app in
                let req = Request(application: app, url: "", on: app.eventLoopGroup.next())
                req.parameters.set("owner", to: "owner")
                req.parameters.set("repository", to: "repo")
                req.parameters.set("reference", to: "~")
                req.parameters.set("archive", to: "archive")

                do { // No cache value available and we've not set up the db with a record to be found -> notFound must be raised
                    _ = try await req.getDocRoute(fragment: .documentation)
                    Issue.record("expected a .notFound error")
                } catch let error as Abort where error.status == .notFound {
                    // expected error
                } catch {
                    Issue.record("unexpected error: \(error)")
                }

                @Dependency(\.currentReferenceCache) var cache
                await cache.set(owner: "owner", repository: "repo", reference: "1.2.3")

                do { // Now with the cache in place this resolves
                    let route = try await req.getDocRoute(fragment: .documentation)
                    #expect(route == .init(owner: "owner", repository: "repo", docVersion: .current(referencing: "1.2.3"), fragment: .documentation, pathElements: ["archive"]))
                }
            }
        }
    }

    @Test func getDocRoute_missing_reference() async throws {
        try await withApp { app in
            do {
                let req = Request(application: app, on: app.eventLoopGroup.next())
                req.parameters.set("owner", to: "owner")
                req.parameters.set("repository", to: "repo")
                _ = try await req.getDocRoute(fragment: .documentation)
                Issue.record("expected a .badRequest error")
            } catch let error as Abort where error.status == .badRequest {
                // expected error
            } catch {
                Issue.record("unexpected error: \(error)")
            }
        }
    }

    @Test func getDocRoute_missing_archive() async throws {
        // reference but no archive
        try await withApp { app in
            do {
                let req = Request(application: app, on: app.eventLoopGroup.next())
                req.parameters.set("owner", to: "owner")
                req.parameters.set("repository", to: "repo")
                req.parameters.set("reference", to: "1.2.3")
                _ = try await req.getDocRoute(fragment: .documentation)
                Issue.record("expected a .badRequest error")
            } catch let error as Abort where error.status == .badRequest {
                // expected error
            } catch {
                Issue.record("unexpected error: \(error)")
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

private extension String {
    static func mockIndexHTML(baseURL: String = "/") -> Self {
        let baseURL = baseURL.hasSuffix("/") ? baseURL : baseURL + "/"
        return """
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
            """
    }
}
