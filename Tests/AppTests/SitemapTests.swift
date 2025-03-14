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
import DependenciesTestSupport
import SnapshotTesting
import Testing
import Vapor

@preconcurrency import Plot


extension AllTests.SitemapTests {

    @Test(.dependency(\.date.now, .t0))
    func siteMapIndex() async throws {
        try await withApp { app in
            // Setup
            let packages = (0..<3).map { Package(url: "\($0)".url) }
            try await packages.save(on: app.db)
            try await packages.map { try Repository(package: $0, defaultBranch: "default",
                                                    lastCommitDate: .t0, name: $0.url,
                                                    owner: "foo") }.save(on: app.db)
            try await packages.map { try Version(package: $0, packageName: "foo",
                                                 reference: .branch("default")) }.save(on: app.db)
            try await Search.refresh(on: app.db)

            let req = Request(application: app, on: app.eventLoopGroup.next())

            // MUT
            let siteMapIndex = try await SiteMapController.index(req: req)

            // Validation
            assertSnapshot(of: siteMapIndex.render(indentedBy: .spaces(2)),
                           as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

    @Test func siteMapIndex_prod() async throws {
        // Ensure sitemap routing is configured in prod
        try await withDependencies {
            $0.date.now = .t0
            $0.environment.current = { .production }
            $0.httpClient.postPlausibleEvent = App.HTTPClient.noop
        } operation: {
            try await withApp(environment: .production) { app in
                // MUT
                try await app.test(.GET, "/sitemap.xml") { res async in
                    // Validation
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func siteMapIndex_dev() async throws {
        // Ensure we don't serve sitemaps in dev
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp(environment: .development) { app in
                // MUT
                try await app.test(.GET, "/sitemap.xml") { res async in
                    // Validation
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func siteMapStaticPages() async throws {
        try await withApp { app in
            let req = Request(application: app, on: app.eventLoopGroup.next())

            // MUT
            let siteMap = try await SiteMapController.staticPages(req: req)

            // Validation
            assertSnapshot(of: siteMap.render(indentedBy: .spaces(2)),
                           as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

    @Test func siteMapStaticPages_prod() async throws {
        // Ensure sitemap routing is configured in prod
        try await withDependencies {
            $0.environment.current = { .production }
            $0.httpClient.postPlausibleEvent = App.HTTPClient.noop
        } operation: {
            try await withApp(environment: .production) { app in
                // MUT
                try await app.test(.GET, "/sitemap-static-pages.xml") { res async in
                    // Validation
                    #expect(res.status == .ok)
                }
            }
        }
    }

    @Test func siteMapStaticPages_dev() async throws {
        // Ensure we don't serve sitemaps in dev
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp(environment: .development) { app in
                // MUT
                try await app.test(.GET, "/sitemap-static-pages.xml") { res async in
                    // Validation
                    #expect(res.status == .notFound)
                }
            }
        }
    }

    @Test func linkablePathUrls() async throws {
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.environment.siteURL = { "https://spi.com" }
            $0.httpClient.fetchDocumentation = { @Sendable url in
                guard url.path.hasSuffix("/owner/repo0/default/linkable-paths.json") else { throw Abort(.notFound) }
                return .ok(body: """
                            [
                                "/documentation/foo/bar/1",
                                "/documentation/foo/bar/2",
                            ]
                            """)
            }
        } operation: {
            try await withApp { app in
                // setup
                let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
                try await package.save(on: app.db)
                try await Repository(package: package, defaultBranch: "default",
                                     lastCommitDate: Date.now,
                                     name: "Repo0", owner: "Owner").save(on: app.db)
                try await Version(package: package,
                                  commit: "123456",
                                  commitDate: .t0,
                                  docArchives: [.init(name: "t1", title: "T1")],
                                  latest: .defaultBranch,
                                  packageName: "SomePackage",
                                  reference: .branch("default"),
                                  spiManifest: .init(builder: .init(configs: [.init(documentationTargets: ["t1", "t2"])]))).save(on: app.db)
                let packageResult = try await PackageController.PackageResult
                    .query(on: app.db, owner: "owner", repository: "repo0")

                // MUT
                let urls = await PackageController.linkablePathUrls(client: app.client, packageResult: packageResult)

                #expect(urls == [
                    "https://spi.com/Owner/Repo0/default/documentation/foo/bar/1",
                    "https://spi.com/Owner/Repo0/default/documentation/foo/bar/2"
                ])
            }
        }
    }

    @Test func linkablePathUrls_reference_pathEncoded() async throws {
        // Ensure branch names with / are properly "path encoded"
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2462
        try await withDependencies {
            $0.environment.awsDocsBucket = { "docs-bucket" }
            $0.environment.siteURL = { "https://spi.com" }
            $0.httpClient.fetchDocumentation = { @Sendable url in
                guard url.path.hasSuffix("/owner/repo0/a-b/linkable-paths.json") else { throw Abort(.notFound) }
                return .ok(body: """
                            [
                                "/documentation/foo/bar/1",
                                "/documentation/foo/bar/2",
                            ]
                            """)
            }
        } operation: {
            try await withApp { app in
                // setup
                let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
                try await package.save(on: app.db)
                try await Repository(package: package, defaultBranch: "a/b",
                                     lastCommitDate: Date.now,
                                     name: "Repo0", owner: "Owner").save(on: app.db)
                try await Version(package: package,
                                  commit: "123456",
                                  commitDate: .t0,
                                  docArchives: [.init(name: "t1", title: "T1")],
                                  latest: .defaultBranch,
                                  packageName: "SomePackage",
                                  reference: .branch("a/b"),
                                  spiManifest: .init(builder: .init(configs: [.init(documentationTargets: ["t1", "t2"])]))).save(on: app.db)
                let packageResult = try await PackageController.PackageResult
                    .query(on: app.db, owner: "owner", repository: "repo0")

                // MUT
                let urls = await PackageController.linkablePathUrls(client: app.client, packageResult: packageResult)

                #expect(urls == [
                    "https://spi.com/Owner/Repo0/a-b/documentation/foo/bar/1",
                    "https://spi.com/Owner/Repo0/a-b/documentation/foo/bar/2"
                ])
            }
        }
    }

    @Test func siteMapForPackage_noDocs() async throws {
        try await withApp { app in
            // setup
            let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
            try await package.save(on: app.db)
            try await Repository(package: package, defaultBranch: "default",
                                 lastCommitDate: .t0,
                                 name: "Repo0", owner: "Owner").save(on: app.db)
            try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                              reference: .branch("default")).save(on: app.db)
            let packageResult = try await PackageController.PackageResult
                .query(on: app.db, owner: "owner", repository: "repo0")

            // MUT
            let sitemap = try await SiteMapController.package(owner: packageResult.repository.owner,
                                                              repository: packageResult.repository.name,
                                                              lastActivityAt: packageResult.repository.lastActivityAt,
                                                              linkablePathUrls: [])
            let xml = sitemap.render(indentedBy: .spaces(2))

            // Validation
            assertSnapshot(of: xml, as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

    @Test func siteMapForPackage_withDocs() async throws {
        try await withApp { app in
            // setup
            let package = Package(url: URL(stringLiteral: "https://example.com/owner/repo0"))
            try await package.save(on: app.db)
            try await Repository(package: package, defaultBranch: "default",
                                 lastCommitDate: .t0,
                                 name: "Repo0", owner: "Owner").save(on: app.db)
            try await Version(package: package, latest: .defaultBranch, packageName: "SomePackage",
                              reference: .branch("default")).save(on: app.db)
            let packageResult = try await PackageController.PackageResult
                .query(on: app.db, owner: "owner", repository: "repo0")
            let linkablePathUrls = [
                "/documentation/semanticversion/semanticversion/minor",
                "/documentation/semanticversion/semanticversion/_(_:_:)-4ftn7",
                "/documentation/semanticversion/semanticversion/'...(_:)-40b95"
            ]

            // MUT
            let sitemap = try await SiteMapController.package(owner: packageResult.repository.owner,
                                                              repository: packageResult.repository.name,
                                                              lastActivityAt: packageResult.repository.lastActivityAt,
                                                              linkablePathUrls: linkablePathUrls)
            let xml = sitemap.render(indentedBy: .spaces(2))

            // Validation
            assertSnapshot(of: xml, as: .init(pathExtension: "xml", diffing: .lines))
        }
    }

}
