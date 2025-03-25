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

import Basics
import Dependencies
import PackageCollectionsSigning
import SnapshotTesting
import Testing
import Vapor


extension AllTests.PackageCollectionTests {

    typealias VersionResult = PackageCollection.VersionResult
    typealias VersionResultGroup = PackageCollection.VersionResultGroup

    var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    @Test func query_filter_urls() async throws {
        // Tests PackageResult.query with the url filter option
        try await withApp { app in
            // setup
            for index in (0..<3) {
                let pkg = try await savePackage(on: app.db, "url-\(index)".url)
                do {
                    let v = try Version(package: pkg,
                                        latest: .release,
                                        packageName: "package \(index)",
                                        reference: .tag(1, 2, 3),
                                        toolsVersion: "5.4")
                    try await v.save(on: app.db)
                    try await Build(version: v,
                                    buildCommand: "build \(index)",
                                    platform: .iOS,
                                    status: .ok,
                                    swiftVersion: .v1)
                    .save(on: app.db)
                    try await Product(version: v,
                                      type: .library(.automatic),
                                      name: "product \(index)")
                    .save(on: app.db)
                    try await Target(version: v, name: "target \(index)")
                        .save(on: app.db)
                }
                try await Repository(package: pkg,
                                     name: "repo \(index)")
                .save(on: app.db)
            }

            // MUT
            let res = try await VersionResult.query(on: app.db, filterBy: .urls(["url-1"]))

            // validate selection and all relations being loaded
            #expect(res.map(\.version.packageName) == ["package 1"])
            #expect(res.flatMap{ $0.builds.map(\.buildCommand) } == ["build 1"])
            #expect(res.flatMap{ $0.products.map(\.name) } == ["product 1"])
            #expect(res.flatMap{ $0.targets.map(\.name) } == ["target 1"])
            #expect(res.map(\.package.url) == ["url-1"])
            #expect(res.map(\.repository.name) == ["repo 1"])
            // drill into relations of relations
            #expect(res.flatMap { $0.version.products.map(\.name) } == ["product 1"])
        }
    }

    @Test func query_filter_urls_no_results() async throws {
        // Tests PackageResult.query without results has safe relationship accessors
        try await withApp { app in
            // setup
            for index in (0..<3) {
                let pkg = try await savePackage(on: app.db, "url-\(index)".url)
                do {
                    let v = try Version(package: pkg,
                                        latest: .release,
                                        packageName: "package \(index)",
                                        reference: .tag(1, 2, 3),
                                        toolsVersion: "5.4")
                    try await v.save(on: app.db)
                    try await Build(version: v,
                                    buildCommand: "build \(index)",
                                    platform: .iOS,
                                    status: .ok,
                                    swiftVersion: .v1)
                    .save(on: app.db)
                    try await Product(version: v,
                                      type: .library(.automatic),
                                      name: "product \(index)")
                    .save(on: app.db)
                    try await Target(version: v, name: "target \(index)")
                        .save(on: app.db)
                }
                try await Repository(package: pkg,
                                     name: "repo \(index)")
                .save(on: app.db)
            }

            // MUT
            let res = try await VersionResult.query(
                on: app.db,
                filterBy: .urls(["non-existant"])
            )

            // validate safe access
            #expect(res.map(\.version.packageName) == [])
            #expect(res.flatMap{ $0.builds.map(\.buildCommand) } == [])
            #expect(res.flatMap{ $0.products.map(\.name) } == [])
            #expect(res.flatMap{ $0.targets.map(\.name) } == [])
            #expect(res.map(\.package.url) == [])
            #expect(res.map(\.repository.name) == [])
        }
    }

    @Test func query_author() async throws {
        // Tests PackageResult.query with the author filter option
        try await withApp { app in
            // setup
            // first package
            let owners = ["foo", "foo", "someone else"]
            for index in (0..<3) {
                let pkg = try await savePackage(on: app.db, "url-\(index)".url)
                do {
                    let v = try Version(package: pkg,
                                        latest: .release,
                                        packageName: "package \(index)",
                                        reference: .tag(1, 2, 3),
                                        toolsVersion: "5.4")
                    try await v.save(on: app.db)
                    try await Build(version: v,
                                    buildCommand: "build \(index)",
                                    platform: .iOS,
                                    status: .ok,
                                    swiftVersion: .v1)
                    .save(on: app.db)
                    try await Product(version: v,
                                      type: .library(.automatic),
                                      name: "product \(index)")
                    .save(on: app.db)
                    try await Target(version: v, name: "target \(index)")
                        .save(on: app.db)
                }
                try await Repository(package: pkg,
                                     name: "repo \(index)",
                                     owner: owners[index])
                .save(on: app.db)
            }

            // MUT
            let res = try await VersionResult.query(on: app.db, filterBy: .author("foo"))

            // validate selection (relationship loading is tested in test_query_filter_urls)
            #expect(res.map(\.version.packageName) == ["package 0", "package 1"])
        }
    }

    @Test func query_custom() async throws {
        // Tests PackageResult.query with the custom collection filter option
        try await withApp { app in
            // setup
            let packages = try await (0..<3).mapAsync { index in
                let pkg = try await savePackage(on: app.db, "url-\(index)".url)
                do {
                    let v = try Version(package: pkg,
                                        latest: .release,
                                        packageName: "package \(index)",
                                        reference: .tag(1, 2, 3),
                                        toolsVersion: "5.4")
                    try await v.save(on: app.db)
                    try await Build(version: v,
                                    buildCommand: "build \(index)",
                                    platform: .iOS,
                                    status: .ok,
                                    swiftVersion: .v1)
                    .save(on: app.db)
                    try await Product(version: v, type: .library(.automatic), name: "product \(index)")
                        .save(on: app.db)
                    try await Target(version: v, name: "target \(index)")
                        .save(on: app.db)
                }
                try await Repository(package: pkg, name: "repo \(index)", owner: "owner")
                    .save(on: app.db)
                return pkg
            }
            let collection = CustomCollection(id: .id2, .init(key: "list",
                                                              name: "List",
                                                              url: "https://github.com/foo/bar/list.json"))
            try await collection.save(on: app.db)
            try await collection.$packages.attach([packages[0], packages[1]], on: app.db)

            // MUT
            let res = try await VersionResult.query(on: app.db,
                                                    filterBy: .customCollection("list"))

            // validate selection (relationship loading is tested in test_query_filter_urls)
            #expect(res.map(\.version.packageName) == ["package 0", "package 1"])
        }
    }

    @Test func Version_init() async throws {
        // Tests PackageCollection.Version initialisation from App.Version
        try await withApp { app in
            // setup
            let p = Package(url: "1")
            try await p.save(on: app.db)
            do {
                let v = try Version(package: p,
                                    latest: .release,
                                    packageName: "Foo",
                                    publishedAt: Date(timeIntervalSince1970: 0),
                                    reference: .tag(1, 2, 3),
                                    releaseNotes: "Bar",
                                    supportedPlatforms: [.ios("14.0")],
                                    toolsVersion: "5.3")
                try await v.save(on: app.db)
                try await Repository(package: p).save(on: app.db)
                do {
                    try await Product(version: v,
                                      type: .library(.automatic),
                                      name: "P1",
                                      targets: ["T1"]).save(on: app.db)
                    try await Product(version: v,
                                      type: .library(.automatic),
                                      name: "P2",
                                      targets: ["T2"]).save(on: app.db)
                }
                do {
                    try await Target(version: v, name: "T1").save(on: app.db)
                    try await Target(version: v, name: "T-2").save(on: app.db)
                }
                do {
                    try await Build(version: v,
                                    platform: .iOS,
                                    status: .ok,
                                    swiftVersion: .v1).save(on: app.db)
                    try await Build(version: v,
                                    platform: .macosXcodebuild,
                                    status: .ok,
                                    swiftVersion: .v2).save(on: app.db)
                }
            }
            let v = try #require(try await VersionResult.query(on: app.db,filterBy: .urls(["1"])).first?.version)

            // MUT
            let res = try #require(
                PackageCollection.Package.Version(version: v, license: .init(name: "MIT", url: "https://foo/mit"))
            )

            // validate the version
            #expect(res.version == "1.2.3")
            #expect(res.summary == "Bar")
            #expect(res.verifiedCompatibility == [
                .init(platform: .init(name: "ios"), swiftVersion: .init("5.8")),
                .init(platform: .init(name: "macos"), swiftVersion: .init("5.9")),
            ])
            #expect(res.license == .init(name: "MIT", url: URL(string: "https://foo/mit")!))
            #expect(res.createdAt == Date(timeIntervalSince1970: 0))

            // The spec requires there to be a dictionary keyed by the default tools version.
            let manifest = try #require(res.manifests[res.defaultToolsVersion])

            // Validate the manifest.
            #expect(manifest.packageName == "Foo")
            #expect(
                manifest.products == [.init(name: "P1", type: .library(.automatic), targets: ["T1"]),
                                      .init(name: "P2", type: .library(.automatic), targets: ["T2"])])
            #expect(
                manifest.targets == [.init(name: "T1", moduleName: "T1"),
                                     .init(name: "T-2", moduleName: "T_2")])
            #expect(manifest.toolsVersion == "5.3")
            #expect(manifest.minimumPlatformVersions == [.init(name: "ios", version: "14.0")])
        }
    }

    @Test func Package_init() async throws {
        // Tests PackageCollection.Package initialisation from App.Package
        try await withApp { app in
            // setup
            do {
                let p = Package(url: "1")
                try await p.save(on: app.db)
                try await Repository(package: p,
                                     license: .mit,
                                     licenseUrl: "https://foo/mit",
                                     readmeHtmlUrl: "readmeUrl",
                                     summary: "summary")
                .save(on: app.db)
                let v = try Version(package: p,
                                    latest: .release,
                                    packageName: "Foo",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.3")
                try await v.save(on: app.db)
                try await Product(version: v,
                                  type: .library(.automatic),
                                  name: "product").save(on: app.db)
            }
            let result = try #require(
                try await VersionResult.query(on: app.db, filterBy: .urls(["1"])).first
            )
            let group = VersionResultGroup(package: result.package,
                                           repository: result.repository,
                                           versions: [result.version])

            // MUT
            let res = try #require(
                PackageCollection.Package(resultGroup: group,
                                          keywords: ["a", "b"])
            )

            // validate
            #expect(res.keywords == ["a", "b"])
            #expect(res.summary == "summary")
            #expect(res.readmeURL == "readmeUrl")
            #expect(res.license?.name == "MIT")
            // version details tested in test_Version_init
            // simply assert count here
            #expect(res.versions.count == 1)
        }
    }

    @Test func groupedByPackage() async throws {
        try await withApp { app in
            // setup
            // 2 packages by the same author (which we select) with two versions
            // each.
            do {
                let p = Package(url: "2")
                try await p.save(on: app.db)
                try await Repository(
                    package: p,
                    owner: "a"
                ).save(on: app.db)
                try await Version(package: p, latest: .release, packageName: "2a")
                    .save(on: app.db)
                try await Version(package: p, latest: .release, packageName: "2b")
                    .save(on: app.db)
            }
            do {
                let p = Package(url: "1")
                try await p.save(on: app.db)
                try await Repository(
                    package: p,
                    owner: "a"
                ).save(on: app.db)
                try await Version(package: p, latest: .release, packageName: "1a")
                    .save(on: app.db)
                try await Version(package: p, latest: .release, packageName: "1b")
                    .save(on: app.db)
            }
            let results = try await VersionResult.query(on: app.db, filterBy: .author("a"))

            // MUT
            let res = results.groupedByPackage(sortBy: .url)

            // validate
            #expect(res.map(\.package.url) == ["1", "2"])
            #expect(
                res.first
                    .flatMap { $0.versions.compactMap(\.packageName) }?
                    .sorted() == ["1a", "1b"]
            )
            #expect(
                res.last
                    .flatMap { $0.versions.compactMap(\.packageName) }?
                    .sorted() == ["2a", "2b"]
            )
        }
    }

    @Test func groupedByPackage_empty() throws {
        // MUT
        let res = [VersionResult]().groupedByPackage()

        // validate
        #expect(res.isEmpty)
    }

    @Test func generate_from_urls() async throws {
        try await withDependencies {
            $0.date.now = .init(timeIntervalSince1970: 1610112345)
        } operation: {
            try await withApp { app in
                // setup
                let pkg = try await savePackage(on: app.db, "1")
                do {
                    let v = try Version(package: pkg,
                                        latest: .release,
                                        packageName: "package",
                                        reference: .tag(1, 2, 3),
                                        toolsVersion: "5.4")
                    try await v.save(on: app.db)
                    try await Product(version: v, type: .library(.automatic), name: "product")
                        .save(on: app.db)
                }
                try await Repository(package: pkg,
                                     license: .mit,
                                     licenseUrl: "https://foo/mit",
                                     summary: "summary").create(on: app.db)

                // MUT
                let res = try await PackageCollection.generate(db: app.db,
                                                               filterBy: .urls(["1"]),
                                                               authorName: "Foo",
                                                               collectionName: "Foo",
                                                               keywords: ["key", "word"],
                                                               overview: "overview")

                assertSnapshot(of: res, as: .json(encoder))
            }
        }
    }

    @Test func generate_from_urls_noResults() async throws {
        try await withApp { app in
            // MUT
            do {
                _ = try await PackageCollection.generate(db: app.db,
                                                         filterBy: .urls(["1"]),
                                                         authorName: "Foo",
                                                         collectionName: "Foo",
                                                         keywords: ["key", "word"],
                                                         overview: "overview")
                Issue.record("Expected error")
            } catch let error as PackageCollection.Error {
                #expect(error == .noResults)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test func generate_for_owner() async throws {
        try await withDependencies {
            $0.date.now = .init(timeIntervalSince1970: 1610112345)
        } operation: {
            try await withApp { app in
                // setup
                // first package
                let p1 = try await savePackage(on: app.db, "https://github.com/foo/1")
                do {
                    let v = try Version(id: UUID(),
                                        package: p1,
                                        packageName: "P1-main",
                                        reference: .branch("main"),
                                        toolsVersion: "5.0")
                    try await v.save(on: app.db)
                    try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                        .save(on: app.db)
                }
                do {
                    let v = try Version(id: UUID(),
                                        package: p1,
                                        latest: .release,
                                        packageName: "P1-tag",
                                        reference: .tag(2, 0, 0),
                                        toolsVersion: "5.2")
                    try await v.save(on: app.db)
                    try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                        .save(on: app.db)
                    try await Build(version: v,
                                    platform: .iOS,
                                    status: .ok,
                                    swiftVersion: .init(5, 6, 0)).save(on: app.db)
                    try await Target(version: v, name: "t1").save(on: app.db)
                }
                // second package
                let p2 = try await savePackage(on: app.db, "https://github.com/foo/2")
                do {
                    let v = try Version(id: UUID(),
                                        package: p2,
                                        packageName: "P2-main",
                                        reference: .branch("main"),
                                        toolsVersion: "5.3")
                    try await v.save(on: app.db)
                    try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                        .save(on: app.db)
                }
                do {
                    let v = try Version(id: UUID(),
                                        package: p2,
                                        latest: .release,
                                        packageName: "P2-tag",
                                        reference: .tag(1, 2, 3),
                                        toolsVersion: "5.3")
                    try await v.save(on: app.db)
                    try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t2"])
                        .save(on: app.db)
                    try await Target(version: v, name: "t2").save(on: app.db)
                }
                // unrelated package
                _ = try await savePackage(on: app.db, "https://github.com/bar/1")
                try await Repository(package: p1,
                                     defaultBranch: "main",
                                     license: .mit,
                                     licenseUrl: "https://foo/mit",
                                     owner: "foo",
                                     summary: "summary 1").create(on: app.db)
                try await Repository(package: p2,
                                     defaultBranch: "main",
                                     license: .mit,
                                     licenseUrl: "https://foo/mit",
                                     owner: "foo",
                                     summary: "summary 2").create(on: app.db)

                // MUT
                let res = try await PackageCollection.generate(db: app.db,
                                                               filterBy: .author("foo"),
                                                               authorName: "Foo",
                                                               keywords: ["key", "word"])

                assertSnapshot(of: res, as: .json(encoder))
            }
        }
    }

    @Test func generate_for_owner_noResults() async throws {
        // Ensure we return noResults when no packages are found
        try await withApp { app in
            // MUT
            do {
                _ = try await PackageCollection.generate(db: app.db,
                                                         filterBy: .author("foo"),
                                                         authorName: "Foo",
                                                         keywords: ["key", "word"])
                Issue.record("Expected error")
            } catch let error as PackageCollection.Error {
                #expect(error == .noResults)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test func includes_significant_versions_only() async throws {
        // Ensure we only export significant versions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1147
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "https://github.com/foo/1")
            try await Repository(package: p,
                                 defaultBranch: "main",
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 owner: "foo",
                                 summary: "summary").create(on: app.db)
            do {  // default branch revision
                let v = try Version(id: UUID(),
                                    package: p,
                                    latest: .defaultBranch,
                                    packageName: "P1-main",
                                    reference: .branch("main"),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }
            do {  // latest release
                let v = try Version(id: UUID(),
                                    package: p,
                                    latest: .release,
                                    packageName: "P1-main",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }
            do {  // older release
                let v = try Version(id: UUID(),
                                    package: p,
                                    latest: nil,
                                    packageName: "P1-main",
                                    reference: .tag(1, 0, 0),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }
            do {  // latest beta release
                let v = try Version(id: UUID(),
                                    package: p,
                                    latest: .preRelease,
                                    packageName: "P1-main",
                                    reference: .tag(2, 0, 0, "b1"),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }
            do {  // older beta release
                let v = try Version(id: UUID(),
                                    package: p,
                                    latest: nil,
                                    packageName: "P1-main",
                                    reference: .tag(1, 5, 0, "b1"),
                                    toolsVersion: "5.0")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib")
                    .save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }

            try await withDependencies {
                $0.date.now = .now
            } operation: {
                // MUT
                let res = try await PackageCollection.generate(db: app.db,
                                                               filterBy: .author("foo"),
                                                               authorName: "Foo",
                                                               collectionName: "Foo",
                                                               keywords: ["key", "word"],
                                                               overview: "overview")

                // validate
                #expect(res.packages.count == 1)
                #expect(res.packages.flatMap { $0.versions.map({$0.version}) } == ["2.0.0-b1", "1.2.3"])
            }
        }
    }

    @Test func require_products() async throws {
        // Ensure we don't include versions without products (by ensuring
        // init? returns nil, which will be compact mapped away)
        try await withApp { app in
            let p = Package(url: "1".asGithubUrl.url)
            try await p.save(on: app.db)
            let v = try Version(package: p,
                                packageName: "pkg",
                                reference: .tag(1,2,3),
                                toolsVersion: "5.3")
            try await v.save(on: app.db)
            try await v.$builds.load(on: app.db)
            try await v.$products.load(on: app.db)
            try await v.$targets.load(on: app.db)
            #expect(PackageCollection.Package.Version(version: v, license: nil) == nil)
        }
    }

    @Test func require_versions() async throws {
        // Ensure we don't include packages without versions (by ensuring
        // init? returns nil, which will be compact mapped away)
        try await withApp { app in
            do {  // no versions at all
                  // setup
                let pkg = Package(url: "1")
                try await pkg.save(on: app.db)
                let repo = try Repository(package: pkg)
                try await repo.save(on: app.db)
                let group = VersionResultGroup(package: pkg,
                                               repository: repo,
                                               versions: [])

                // MUT
                #expect(PackageCollection.Package(resultGroup: group, keywords: nil) == nil)
            }

            do {  // only invalid versions
                  // setup
                do {
                    let p = Package(url: "2")
                    try await p.save(on: app.db)
                    try await Version(package: p, latest: .release).save(on: app.db)
                    try await Repository(package: p).save(on: app.db)
                }
                let res = try #require(
                    try await VersionResult.query(on: app.db, filterBy: .urls(["2"])).first
                )
                let group = VersionResultGroup(package: res.package,
                                               repository: res.repository,
                                               versions: [res.version])

                // MUT
                #expect(PackageCollection.Package(resultGroup: group, keywords: nil) == nil)
            }
        }
    }

    @Test func case_insensitive_owner_matching() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "https://github.com/foo/1")
            do {
                let v = try Version(id: UUID(),
                                    package: pkg,
                                    latest: .release,
                                    packageName: "P1-tag",
                                    reference: .tag(2, 0, 0),
                                    toolsVersion: "5.2")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                    .save(on: app.db)
            }
            // Owner "Foo"
            try await Repository(package: pkg,
                                 defaultBranch: "main",
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 owner: "Foo",
                                 summary: "summary 1").create(on: app.db)

            try await withDependencies {
                $0.date.now = .now
            } operation: {
                // MUT
                let res = try await PackageCollection.generate(db: app.db,
                                                               // looking for owner "foo"
                                                               filterBy: .author("foo"),
                                                               collectionName: "collection")

                // validate
                #expect(res.packages.count == 1)
            }
        }
    }

    @Test func generate_ownerName() async throws {
        // Ensure ownerName is used in collectionName and overview
        try await withApp { app in
            // setup
            // first package
            let p1 = try await savePackage(on: app.db, "https://github.com/foo/1")
            do {
                let v = try Version(id: UUID(),
                                    package: p1,
                                    latest: .release,
                                    packageName: "P1-tag",
                                    reference: .tag(2, 0, 0),
                                    toolsVersion: "5.2")
                try await v.save(on: app.db)
                try await Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                    .save(on: app.db)
                try await Build(version: v,
                                platform: .iOS,
                                status: .ok,
                                swiftVersion: .v2).save(on: app.db)
                try await Target(version: v, name: "t1").save(on: app.db)
            }
            // unrelated package
            try await Repository(package: p1,
                                 defaultBranch: "main",
                                 license: .mit,
                                 licenseUrl: "https://foo/mit",
                                 owner: "foo",
                                 ownerName: "Foo Org",
                                 summary: "summary 1").create(on: app.db)

            try await withDependencies {
                $0.date.now = .now
            } operation: {
                // MUT
                let res = try await PackageCollection.generate(db: app.db,
                                                               filterBy: .author("foo"),
                                                               authorName: "Foo",
                                                               keywords: ["key", "word"])

                // validate
                #expect(res.name == "Packages by Foo Org")
                #expect(res.overview == "A collection of packages authored by Foo Org from the Swift Package Index")
            }
        }
    }

    @Test func Compatibility() throws {
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
            .init(versionId: .id0, platform: .iOS, status: .ok, swiftVersion: .v3),
            .init(versionId: .id0, platform: .iOS, status: .ok, swiftVersion: .v2),
            .init(versionId: .id0, platform: .iOS, status: .ok, swiftVersion: .v1),
        ])
        // MUT
        let res = [PackageCollection.Compatibility].init(builds: builds)
        // validate
        #expect(res.count == 3)
        #expect(res.map(\.platform).sorted() == [.init(name: "ios"), .init(name: "ios"), .init(name: "ios")])
        #expect(res.map(\.swiftVersion).sorted() == [SwiftVersion.v1, .v2, .v3].map { $0.description(droppingZeroes: .patch) }.sorted())
    }

    @Test func authorLabel() async throws {
        try await withApp { app in
            // setup
            let p = Package(url: "1")
            try await p.save(on: app.db)
            let repositories = try (0..<3).map {
                try Repository(package: p, owner: "owner-\($0)")
            }

            // MUT & validate
            #expect(
                PackageCollection.authorLabel(repositories: []) == nil
            )
            #expect(
                PackageCollection.authorLabel(repositories: Array(repositories.prefix(1))) == "owner-0"
            )
            #expect(
                PackageCollection.authorLabel(repositories: Array(repositories.prefix(2))) == "owner-0 and owner-1"
            )
            #expect(
                PackageCollection.authorLabel(repositories: repositories) == "multiple authors"
            )
        }
    }

    @Test(
        .disabled(
            if: !isRunningInCI() && EnvironmentClient.liveValue.collectionSigningPrivateKey() == nil,
            "Skip test for local user due to unset COLLECTION_SIGNING_PRIVATE_KEY env variable"
        )
    )
    func sign_collection() async throws {
        try await withDependencies {
            $0.environment.collectionSigningCertificateChain = EnvironmentClient.liveValue.collectionSigningCertificateChain
            $0.environment.collectionSigningPrivateKey = EnvironmentClient.liveValue.collectionSigningPrivateKey
        } operation: {
            // setup
            let collection: PackageCollection = .mock

            // MUT
            let signedCollection = try await SignedCollection.sign(collection: collection)

            // validate signed collection content
            #expect(!signedCollection.signature.signature.isEmpty)
            assertSnapshot(of: signedCollection, as: .json(encoder))

            // validate signature
            let validated = try await SignedCollection.validate(signedCollection: signedCollection)
            #expect(validated)
        }
    }

    @Test(
        .disabled("Skipping until issue is resolved"),
        .bug("https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1583#issuecomment-1066592057")
    )
    func sign_collection_revoked_key() async throws {
        // setup
        let collection: PackageCollection = .mock
        // get cert and key and make sure the inputs are valid (apart from being revoked)
        // so we don't fail for that reason
        let revokedUrl = fixtureUrl(for: "revoked.cer")
        #expect(Foundation.FileManager.default.fileExists(atPath: revokedUrl.path))
        let revokedKey = try fixtureData(for: "revoked.pem")

        await withDependencies {
            $0.environment.collectionSigningCertificateChain = {
                [
                    revokedUrl,
                    SignedCollection.certsDir.appendingPathComponent("AppleWWDRCAG3.cer"),
                    SignedCollection.certsDir.appendingPathComponent("AppleIncRootCertificate.cer")
                ]
            }
            $0.environment.collectionSigningPrivateKey = { revokedKey }
        } operation: {
            do {
                // MUT
                let signedCollection = try await SignedCollection.sign(collection: collection)
                // NB: signing _can_ succeed in case of reachability issues to verify the cert
                // in this case we need to check the signature
                // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1583#issuecomment-1048408400
                let validated = try await SignedCollection.validate(signedCollection: signedCollection)
                #expect(!validated)
            } catch PackageCollectionSigningError.invalidCertChain {
                // ok
            } catch {
                Issue.record("unexpected signing error: \(error)")
            }
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
                              author: nil,
                              signer: .spi,
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
