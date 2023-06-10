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
import SnapshotTesting
import Vapor
import XCTest

import Basics
import PackageCollectionsSigning


class PackageCollectionTests: AppTestCase {

    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    typealias VersionResult = PackageCollection.VersionResult
    typealias VersionResultGroup = PackageCollection.VersionResultGroup

    func test_query_filter_urls() throws {
        // Tests PackageResult.query with the url filter option
        // setup
        try (0..<3).forEach { index in
            let pkg = try savePackage(on: app.db, "url-\(index)".url)
            do {
                let v = try Version(package: pkg,
                                    latest: .release,
                                    packageName: "package \(index)",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.4")
                try v.save(on: app.db).wait()
                try Build(version: v,
                          buildCommand: "build \(index)",
                          platform: .ios,
                          status: .ok,
                          swiftVersion: .v1)
                    .save(on: app.db).wait()
                try Product(version: v,
                            type: .library(.automatic),
                            name: "product \(index)")
                    .save(on: app.db).wait()
                try Target(version: v, name: "target \(index)")
                    .save(on: app.db).wait()
            }
            try Repository(package: pkg,
                           name: "repo \(index)")
                .save(on: app.db).wait()
        }

        // MUT
        let res = try VersionResult.query(on: app.db,
                                          filterBy: .urls(["url-1"])).wait()

        // validate selection and all relations being loaded
        XCTAssertEqual(res.map(\.version.packageName), ["package 1"])
        XCTAssertEqual(res.flatMap{ $0.builds.map(\.buildCommand) },
                       ["build 1"])
        XCTAssertEqual(res.flatMap{ $0.products.map(\.name) },
                       ["product 1"])
        XCTAssertEqual(res.flatMap{ $0.targets.map(\.name) },
                       ["target 1"])
        XCTAssertEqual(res.map(\.package.url), ["url-1"])
        XCTAssertEqual(res.map(\.repository.name), ["repo 1"])
        // drill into relations of relations
        XCTAssertEqual(res.flatMap { $0.version.products.map(\.name) }, ["product 1"])
    }

    func test_query_filter_urls_no_results() throws {
        // Tests PackageResult.query without results has safe relationship accessors
        // setup
        try (0..<3).forEach { index in
            let pkg = try savePackage(on: app.db, "url-\(index)".url)
            do {
                let v = try Version(package: pkg,
                                    latest: .release,
                                    packageName: "package \(index)",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.4")
                try v.save(on: app.db).wait()
                try Build(version: v,
                          buildCommand: "build \(index)",
                          platform: .ios,
                          status: .ok,
                          swiftVersion: .v1)
                    .save(on: app.db).wait()
                try Product(version: v,
                            type: .library(.automatic),
                            name: "product \(index)")
                    .save(on: app.db).wait()
                try Target(version: v, name: "target \(index)")
                    .save(on: app.db).wait()
            }
            try Repository(package: pkg,
                           name: "repo \(index)")
                .save(on: app.db).wait()
        }

        // MUT
        let res = try VersionResult.query(
            on: app.db,
            filterBy: .urls(["non-existant"])
        ).wait()

        // validate safe access
        XCTAssertEqual(res.map(\.version.packageName), [])
        XCTAssertEqual(res.flatMap{ $0.builds.map(\.buildCommand) }, [])
        XCTAssertEqual(res.flatMap{ $0.products.map(\.name) }, [])
        XCTAssertEqual(res.flatMap{ $0.targets.map(\.name) }, [])
        XCTAssertEqual(res.map(\.package.url), [])
        XCTAssertEqual(res.map(\.repository.name), [])
    }

    func test_query_author() throws {
        // Tests PackageResult.query with the author filter option
        // setup
        // first package
        let owners = ["foo", "foo", "someone else"]
        try (0..<3).forEach { index in
            let pkg = try savePackage(on: app.db, "url-\(index)".url)
            do {
                let v = try Version(package: pkg,
                                    latest: .release,
                                    packageName: "package \(index)",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.4")
                try v.save(on: app.db).wait()
                try Build(version: v,
                          buildCommand: "build \(index)",
                          platform: .ios,
                          status: .ok,
                          swiftVersion: .v1)
                    .save(on: app.db).wait()
                try Product(version: v,
                            type: .library(.automatic),
                            name: "product \(index)")
                    .save(on: app.db).wait()
                try Target(version: v, name: "target \(index)")
                    .save(on: app.db).wait()
            }
            try Repository(package: pkg,
                           name: "repo \(index)",
                           owner: owners[index])
                .save(on: app.db).wait()
        }

        // MUT
        let res = try VersionResult.query(on: self.app.db,
                                          filterBy: .author("foo"))
            .wait()

        // validate selection (relationship loading is tested in test_query_filter_urls)
        XCTAssertEqual(res.map(\.version.packageName),
                       ["package 0", "package 1"])
    }

    func test_Version_init() throws {
        // Tests PackageCollection.Version initialisation from App.Version
        // setup
        let p = Package(url: "1")
        try p.save(on: app.db).wait()
        do {
            let v = try Version(package: p,
                                latest: .release,
                                packageName: "Foo",
                                publishedAt: Date(timeIntervalSince1970: 0),
                                reference: .tag(1, 2, 3),
                                releaseNotes: "Bar",
                                supportedPlatforms: [.ios("14.0")],
                                toolsVersion: "5.3")
            try v.save(on: app.db).wait()
            try Repository(package: p).save(on: app.db).wait()
            do {
                try Product(version: v,
                            type: .library(.automatic),
                            name: "P1",
                            targets: ["T1"]).save(on: app.db).wait()
                try Product(version: v,
                            type: .library(.automatic),
                            name: "P2",
                            targets: ["T2"]).save(on: app.db).wait()
            }
            do {
                try Target(version: v, name: "T1").save(on: app.db).wait()
                try Target(version: v, name: "T-2").save(on: app.db).wait()
            }
            do {
                try Build(version: v,
                          platform: .ios,
                          status: .ok,
                          swiftVersion: .v1).save(on: app.db).wait()
                try Build(version: v,
                          platform: .macosXcodebuild,
                          status: .ok,
                          swiftVersion: .v2).save(on: app.db).wait()
            }
        }
        let v = try XCTUnwrap(VersionResult.query(on: app.db,
                                                  filterBy: .urls(["1"]))
                                .wait()
                                .first?.version)

        // MUT
        let res = try XCTUnwrap(
            PackageCollection.Package.Version(
                version: v,
                license: .init(name: "MIT", url: "https://foo/mit")
            )
        )

        // validate the version
        XCTAssertEqual(res.version, "1.2.3")
        XCTAssertEqual(res.summary, "Bar")
        XCTAssertEqual(res.verifiedCompatibility, [
            .init(platform: .init(name: "ios"), swiftVersion: .init("5.5")),
            .init(platform: .init(name: "macos"), swiftVersion: .init("5.6")),
        ])
        XCTAssertEqual(res.license, .init(name: "MIT", url: URL(string: "https://foo/mit")!))
        XCTAssertEqual(res.createdAt, Date(timeIntervalSince1970: 0))

        // The spec requires there to be a dictionary keyed by the default tools version.
        let manifest = try XCTUnwrap(res.manifests[res.defaultToolsVersion])

        // Validate the manifest.
        XCTAssertEqual(manifest.packageName, "Foo")
        XCTAssertEqual(
            manifest.products,
            [.init(name: "P1", type: .library(.automatic), targets: ["T1"]),
             .init(name: "P2", type: .library(.automatic), targets: ["T2"])])
        XCTAssertEqual(
            manifest.targets,
            [.init(name: "T1", moduleName: "T1"),
             .init(name: "T-2", moduleName: "T_2")])
        XCTAssertEqual(manifest.toolsVersion, "5.3")
        XCTAssertEqual(manifest.minimumPlatformVersions, [.init(name: "ios", version: "14.0")])
    }

    func test_Package_init() throws {
        // Tests PackageCollection.Package initialisation from App.Package
        // setup
        do {
            let p = Package(url: "1")
            try p.save(on: app.db).wait()
            try Repository(package: p,
                           license: .mit,
                           licenseUrl: "https://foo/mit",
                           readmeUrl: "readmeUrl",
                           summary: "summary")
                .save(on: app.db).wait()
            let v = try Version(package: p,
                                latest: .release,
                                packageName: "Foo",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.3")
            try v.save(on: app.db).wait()
            try Product(version: v,
                        type: .library(.automatic),
                        name: "product").save(on: app.db).wait()
        }
        let result = try XCTUnwrap(
            VersionResult.query(on: app.db, filterBy: .urls(["1"]))
                .wait().first
        )
        let group = VersionResultGroup(package: result.package,
                                       repository: result.repository,
                                       versions: [result.version])

        // MUT
        let res = try XCTUnwrap(
            PackageCollection.Package(resultGroup: group,
                                      keywords: ["a", "b"])
        )

        // validate
        XCTAssertEqual(res.keywords, ["a", "b"])
        XCTAssertEqual(res.summary, "summary")
        XCTAssertEqual(res.readmeURL, "readmeUrl")
        XCTAssertEqual(res.license?.name, "MIT")
        // version details tested in test_Version_init
        // simply assert count here
        XCTAssertEqual(res.versions.count, 1)
    }

    func test_groupedByPackage() throws {
        // setup
        // 2 packages by the same author (which we select) with two versions
        // each.
        do {
            let p = Package(url: "2")
            try p.save(on: app.db).wait()
            try Repository(
                package: p,
                owner: "a"
            ).save(on: app.db).wait()
            try Version(package: p, latest: .release, packageName: "2a")
                .save(on: app.db).wait()
            try Version(package: p, latest: .release, packageName: "2b")
                .save(on: app.db).wait()
        }
        do {
            let p = Package(url: "1")
            try p.save(on: app.db).wait()
            try Repository(
                package: p,
                owner: "a"
            ).save(on: app.db).wait()
            try Version(package: p, latest: .release, packageName: "1a")
                .save(on: app.db).wait()
            try Version(package: p, latest: .release, packageName: "1b")
                .save(on: app.db).wait()
        }
        let results = try VersionResult.query(on: app.db,
                                              filterBy: .author("a")).wait()

        // MUT
        let res = results.groupedByPackage(sortBy: .url)

        // validate
        XCTAssertEqual(res.map(\.package.url), ["1", "2"])
        XCTAssertEqual(
            res.first
                .flatMap { $0.versions.compactMap(\.packageName) }?
                .sorted(),
            ["1a", "1b"]
        )
        XCTAssertEqual(
            res.last
                .flatMap { $0.versions.compactMap(\.packageName) }?
                .sorted(),
            ["2a", "2b"]
        )
    }

    func test_groupedByPackage_empty() throws {
        // MUT
        let res = [VersionResult]().groupedByPackage()

        // validate
        XCTAssertTrue(res.isEmpty)
    }

    func test_generate_from_urls() throws {
        // setup
        Current.date = { Date(timeIntervalSince1970: 1610112345) }
        let pkg = try savePackage(on: app.db, "1")
        do {
            let v = try Version(package: pkg,
                                latest: .release,
                                packageName: "package",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.4")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "product")
                .save(on: app.db).wait()
        }
        try Repository(package: pkg,
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       summary: "summary").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 filterBy: .urls(["1"]),
                                                 authorName: "Foo",
                                                 collectionName: "Foo",
                                                 keywords: ["key", "word"],
                                                 overview: "overview")
            .wait()

        // validate
        assertSnapshot(matching: res, as: .json(encoder))
    }

    func test_generate_from_urls_noResults() throws {
        // MUT
        XCTAssertThrowsError(
            try PackageCollection.generate(db: self.app.db,
                                           filterBy: .urls(["1"]),
                                           authorName: "Foo",
                                           collectionName: "Foo",
                                           keywords: ["key", "word"],
                                           overview: "overview").wait()
        ) {
            XCTAssertEqual($0 as? PackageCollection.Error, .noResults)
        }
    }

    func test_generate_for_owner() throws {
        // setup
        Current.date = { Date(timeIntervalSince1970: 1610112345) }
        // first package
        let p1 = try savePackage(on: app.db, "https://github.com/foo/1")
        do {
            let v = try Version(id: UUID(),
                                package: p1,
                                packageName: "P1-main",
                                reference: .branch("main"),
                                toolsVersion: "5.0")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
        }
        do {
            let v = try Version(id: UUID(),
                                package: p1,
                                latest: .release,
                                packageName: "P1-tag",
                                reference: .tag(2, 0, 0),
                                toolsVersion: "5.2")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db).wait()
            try Build(version: v,
                      platform: .ios,
                      status: .ok,
                      swiftVersion: .v2).save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        // second package
        let p2 = try savePackage(on: app.db, "https://github.com/foo/2")
        do {
            let v = try Version(id: UUID(),
                                package: p2,
                                packageName: "P2-main",
                                reference: .branch("main"),
                                toolsVersion: "5.3")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
        }
        do {
            let v = try Version(id: UUID(),
                                package: p2,
                                latest: .release,
                                packageName: "P2-tag",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.3")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t2"])
                .save(on: app.db).wait()
            try Target(version: v, name: "t2").save(on: app.db).wait()
        }
        // unrelated package
        _ = try savePackage(on: app.db, "https://github.com/bar/1")
        try Repository(package: p1,
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo",
                       summary: "summary 1").create(on: app.db).wait()
        try Repository(package: p2,
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo",
                       summary: "summary 2").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 filterBy: .author("foo"),
                                                 authorName: "Foo",
                                                 keywords: ["key", "word"])
            .wait()

        // validate
        assertSnapshot(matching: res, as: .json(encoder))
    }

    func test_generate_for_owner_noResults() throws {
        // Ensure we return noResults when no packages are found
        // MUT
        XCTAssertThrowsError(
            try PackageCollection.generate(db: self.app.db,
                                           filterBy: .author("foo"),
                                           authorName: "Foo",
                                           keywords: ["key", "word"]).wait()
        ) {
            XCTAssertEqual($0 as? PackageCollection.Error, .noResults)
        }
    }

    func test_includes_significant_versions_only() throws {
        // Ensure we only export significant versions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1147
        // setup
        let p = try savePackage(on: app.db, "https://github.com/foo/1")
        try Repository(package: p,
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo",
                       summary: "summary").create(on: app.db).wait()
        do {  // default branch revision
            let v = try Version(id: UUID(),
                                package: p,
                                latest: .defaultBranch,
                                packageName: "P1-main",
                                reference: .branch("main"),
                                toolsVersion: "5.0")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        do {  // latest release
            let v = try Version(id: UUID(),
                                package: p,
                                latest: .release,
                                packageName: "P1-main",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.0")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        do {  // older release
            let v = try Version(id: UUID(),
                                package: p,
                                latest: nil,
                                packageName: "P1-main",
                                reference: .tag(1, 0, 0),
                                toolsVersion: "5.0")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        do {  // latest beta release
            let v = try Version(id: UUID(),
                                package: p,
                                latest: .preRelease,
                                packageName: "P1-main",
                                reference: .tag(2, 0, 0, "b1"),
                                toolsVersion: "5.0")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        do {  // older beta release
            let v = try Version(id: UUID(),
                                package: p,
                                latest: nil,
                                packageName: "P1-main",
                                reference: .tag(1, 5, 0, "b1"),
                                toolsVersion: "5.0")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 filterBy: .author("foo"),
                                                 authorName: "Foo",
                                                 collectionName: "Foo",
                                                 keywords: ["key", "word"],
                                                 overview: "overview")
            .wait()

        // validate
        XCTAssertEqual(res.packages.count, 1)
        XCTAssertEqual(res.packages.flatMap { $0.versions.map({$0.version}) },
                       ["2.0.0-b1", "1.2.3"])
    }

    func test_require_products() throws {
        // Ensure we don't include versions without products (by ensuring
        // init? returns nil, which will be compact mapped away)
        let p = Package(url: "1".asGithubUrl.url)
        try p.save(on: app.db).wait()
        let v = try Version(package: p,
                            packageName: "pkg",
                            reference: .tag(1,2,3),
                            toolsVersion: "5.3")
        try v.save(on: app.db).wait()
        try v.$builds.load(on: app.db).wait()
        try v.$products.load(on: app.db).wait()
        try v.$targets.load(on: app.db).wait()
        XCTAssertNil(PackageCollection.Package.Version(version: v,
                                                       license: nil))
    }

    func test_require_versions() throws {
        // Ensure we don't include packages without versions (by ensuring
        // init? returns nil, which will be compact mapped away)
        do {  // no versions at all
            // setup
            let pkg = Package(url: "1")
            try pkg.save(on: app.db).wait()
            let repo = try Repository(package: pkg)
            try repo.save(on: app.db).wait()
            let group = VersionResultGroup(package: pkg,
                                           repository: repo,
                                           versions: [])

            // MUT
            XCTAssertNil(PackageCollection.Package(resultGroup: group,
                                                   keywords: nil))
        }

        do {  // only invalid versions
            // setup
            do {
                let p = Package(url: "2")
                try p.save(on: app.db).wait()
                try Version(package: p, latest: .release).save(on: app.db).wait()
                try Repository(package: p).save(on: app.db).wait()
            }
            let res = try XCTUnwrap(
                VersionResult.query(on: app.db, filterBy: .urls(["2"]))
                    .wait().first
            )
            let group = VersionResultGroup(package: res.package,
                                           repository: res.repository,
                                           versions: [res.version])

            // MUT
            XCTAssertNil(PackageCollection.Package(resultGroup: group,
                                                   keywords: nil))
        }
    }

    func test_case_insensitive_owner_matching() throws {
        // setup
        let pkg = try savePackage(on: app.db, "https://github.com/foo/1")
        do {
            let v = try Version(id: UUID(),
                                package: pkg,
                                latest: .release,
                                packageName: "P1-tag",
                                reference: .tag(2, 0, 0),
                                toolsVersion: "5.2")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db).wait()
        }
        // Owner "Foo"
        try Repository(package: pkg,
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "Foo",
                       summary: "summary 1").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 // looking for owner "foo"
                                                 filterBy: .author("foo"),
                                                 collectionName: "collection")
            .wait()

        // validate
        XCTAssertEqual(res.packages.count, 1)
    }

    func test_generate_ownerName() throws {
        // Ensure ownerName is used in collectionName and overview
        // setup
        // first package
        let p1 = try savePackage(on: app.db, "https://github.com/foo/1")
        do {
            let v = try Version(id: UUID(),
                                package: p1,
                                latest: .release,
                                packageName: "P1-tag",
                                reference: .tag(2, 0, 0),
                                toolsVersion: "5.2")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db).wait()
            try Build(version: v,
                      platform: .ios,
                      status: .ok,
                      swiftVersion: .v2).save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        // unrelated package
        try Repository(package: p1,
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo",
                       ownerName: "Foo Org",
                       summary: "summary 1").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 filterBy: .author("foo"),
                                                 authorName: "Foo",
                                                 keywords: ["key", "word"])
            .wait()

        // validate
        XCTAssertEqual(res.name, "Packages by Foo Org")
        XCTAssertEqual(res.overview, "A collection of packages authored by Foo Org from the Swift Package Index")
    }

    func test_Compatibility() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1215
        // setup
        var builds = [Build]()
        // set all build to failed as a baseline...
        for p in Build.Platform.allActive {
            for s in SwiftVersion.allActive {
                builds.append(
                    .init(versionId: .id0, platform: p, status: .failed, swiftVersion: s)
                )
            }
        }
        // ...then append three successful ones
        builds.append(contentsOf: [
            .init(versionId: .id0, platform: .ios, status: .ok, swiftVersion: .v5_7),
            .init(versionId: .id0, platform: .ios, status: .ok, swiftVersion: .v2),
            .init(versionId: .id0, platform: .ios, status: .ok, swiftVersion: .v1),
        ])
        // MUT
        let res = [PackageCollection.Compatibility].init(builds: builds)
        // validate
        XCTAssertEqual(res.count, 3)
        XCTAssertEqual(res.map(\.platform).sorted(),
                       [.init(name: "ios"), .init(name: "ios"), .init(name: "ios")])
        XCTAssertEqual(res.map(\.swiftVersion).sorted(),
                       ["\(SwiftVersion.v1)", "\(SwiftVersion.v2)", "\(SwiftVersion.v5_7)"])
    }

    func test_authorLabel() throws {
        // setup
        let p = Package(url: "1")
        try p.save(on: app.db).wait()
        let repositories = try (0..<3).map {
            try Repository(package: p, owner: "owner-\($0)")
        }

        // MUT & validate
        XCTAssertEqual(
            PackageCollection.authorLabel(repositories: []),
            nil
        )
        XCTAssertEqual(
            PackageCollection.authorLabel(repositories: Array(repositories.prefix(1))),
            "owner-0"
        )
        XCTAssertEqual(
            PackageCollection.authorLabel(repositories: Array(repositories.prefix(2))),
            "owner-0 and owner-1"
        )
        XCTAssertEqual(
            PackageCollection.authorLabel(repositories: repositories),
            "multiple authors"
        )
    }

    func test_sign_collection() throws {
        try XCTSkipIf(!isRunningInCI && Current.collectionSigningPrivateKey() == nil, "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable")

        // setup
        let collection: PackageCollection = .mock

        // MUT
        let signedCollection = try SignedCollection.sign(eventLoop: app.eventLoopGroup.next(),
                                                         collection: collection).wait()

        // validate signed collection content
        XCTAssertFalse(signedCollection.signature.signature.isEmpty)
        assertSnapshot(matching: signedCollection, as: .json(self.encoder))

        // validate signature
        let validated = try SignedCollection.validate(eventLoop: app.eventLoopGroup.next(),
                                                      signedCollection: signedCollection)
            .wait()
        XCTAssertTrue(validated)
    }

    func test_sign_collection_revoked_key() throws {
        // Skipping until https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1583#issuecomment-1066592057
        // is resolved
        try XCTSkipIf(true)

        // setup
        let collection: PackageCollection = .mock
        // get cert and key and make sure the inputs are valid (apart from being revoked)
        // so we don't fail for that reason
        let revokedUrl = fixtureUrl(for: "revoked.cer")
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: revokedUrl.path))
        let revokedKey = try XCTUnwrap(fixtureData(for: "revoked.pem"))

        Current.collectionSigningCertificateChain = {
            [
                revokedUrl,
                SignedCollection.certsDir
                    .appendingPathComponent("AppleWWDRCAG3.cer"),
                SignedCollection.certsDir
                    .appendingPathComponent("AppleIncRootCertificate.cer")
            ]
        }
        Current.collectionSigningPrivateKey = { revokedKey }

        // MUT
        do {
            let signedCollection = try SignedCollection.sign(eventLoop: app.eventLoopGroup.next(),
                                                             collection: collection).wait()
            // NB: signing _can_ succeed in case of reachability issues to verify the cert
            // in this case we need to check the signature
            // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1583#issuecomment-1048408400
            let validated = try SignedCollection.validate(eventLoop: app.eventLoopGroup.next(),
                                                          signedCollection: signedCollection).wait()
            XCTAssertFalse(validated)
        } catch PackageCollectionSigningError.invalidCertChain {
            // ok
        } catch {
            XCTFail("unexpected signing error: \(error)")
        }
    }

}


private extension PackageCollection {
    static var mock: Self {
        .init(
            name: "Collection",
            overview: "Some collection",
            keywords: [],
            packages: [
                .init(url: "url",
                      summary: nil,
                      keywords: nil,
                      versions: [
                        .init(version: "1.2.3",
                              summary: nil,
                              manifests: [
                                "5.5": .init(toolsVersion: "5.5",
                                             packageName: "foo",
                                             targets: [.init(name: "t",
                                                             moduleName: nil)],
                                             products: [.init(name: "p",
                                                              type: .executable,
                                                              targets: ["t"])],
                                             minimumPlatformVersions: nil)
                              ],
                              defaultToolsVersion: "5.5",
                              verifiedCompatibility: nil,
                              license: nil,
                              createdAt: .t0)
                      ],
                      readmeURL: nil,
                      license: nil)
            ],
            formatVersion: .v1_0,
            revision: nil,
            generatedAt: .t0,
            generatedBy: nil
        )
    }
}
