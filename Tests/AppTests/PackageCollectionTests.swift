@testable import App
import SnapshotTesting
import Vapor
import XCTest


class PackageCollectionTests: AppTestCase {

    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func test_Version_init() throws {
        // Tests PackageCollection.Version initialisation from App.Version
        // setup
        let p = Package(url: "1".asGithubUrl.url)
        try p.save(on: app.db).wait()
        do {
            let v = try Version(package: p,
                                packageName: "Foo",
                                publishedAt: Date(timeIntervalSince1970: 0),
                                reference: .tag(1, 2, 3),
                                releaseNotes: "Bar",
                                supportedPlatforms: [.ios("14.0")],
                                toolsVersion: "5.3")
            try v.save(on: app.db).wait()
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
                try Target(version: v, name: "T2").save(on: app.db).wait()
            }
            do {
                try Build(version: v,
                          platform: .ios,
                          status: .ok,
                          swiftVersion: .v5_2).save(on: app.db).wait()
                try Build(version: v,
                          platform: .macosXcodebuild,
                          status: .ok,
                          swiftVersion: .v5_3).save(on: app.db).wait()
                try Build(version: v,
                          platform: .macosXcodebuildArm,
                          status: .ok,
                          swiftVersion: .v5_3).save(on: app.db).wait()
            }
        }
        let v = try Version.query(on: app.db)
            .with(\.$builds)
            .with(\.$products)
            .with(\.$targets)
            .first()
            .unwrap(or: Abort(.notFound))
            .wait()

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
            .init(platform: .init(name: "ios"), swiftVersion: .init("5.2")),
            .init(platform: .init(name: "macos"), swiftVersion: .init("5.3")),
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
            [.init(name: "T1", moduleName: nil),
             .init(name: "T2", moduleName: nil)])
        XCTAssertEqual(manifest.toolsVersion, "5.3")
        XCTAssertEqual(manifest.minimumPlatformVersions, [.init(name: "ios", version: "14.0")])
    }

    func test_Package_init() throws {
        // Tests PackageCollection.Package initialisation from App.Package
        // setup
        do {
            let p = Package(url: "1".asGithubUrl.url)
            try p.save(on: app.db).wait()
            do {
                let r = try Repository(package: p,
                                       summary: "summary",
                                       license: .mit,
                                       licenseUrl: "https://foo/mit",
                                       readmeUrl: "readmeUrl")
                try r.save(on: app.db).wait()
            }
            do {
                let v = try Version(package: p,
                                    packageName: "Foo",
                                    reference: .tag(1, 2, 3),
                                    toolsVersion: "5.3")
                try v.save(on: app.db).wait()
            }
        }
        let p = try Package.query(on: app.db)
            .with(\.$repositories)
            .with(\.$versions) {
                $0.with(\.$builds)
                $0.with(\.$products)
                $0.with(\.$targets)
            }
            .first()
            .unwrap(or: Abort(.notFound))
            .wait()

        // MUT
        let res = try XCTUnwrap(PackageCollection.Package(package: p,
                                                          keywords: ["a", "b"]))

        // validate
        XCTAssertEqual(res.keywords, ["a", "b"])
        XCTAssertEqual(res.summary, "summary")
        XCTAssertEqual(res.readmeURL, "readmeUrl")
        XCTAssertEqual(res.license?.name, "MIT")
        // version details tested in test_Version_init
        // simply assert count here
        XCTAssertEqual(res.versions.count, 1)
    }

    func test_generate_from_urls() throws {
        // setup
        Current.date = { Date(timeIntervalSince1970: 1610112345) }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg,
                       summary: "summary",
                       license: .mit,
                       licenseUrl: "https://foo/mit").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 packageURLs: ["1"],
                                                 authorName: "Foo",
                                                 collectionName: "Foo",
                                                 keywords: ["key", "word"],
                                                 overview: "overview")
            .wait()

        // validate
        assertSnapshot(matching: res, as: .json(encoder))
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
                                packageName: "P1-tag",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.1")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        do {
            let v = try Version(id: UUID(),
                                package: p1,
                                packageName: "P1-tag",
                                reference: .tag(2, 0, 0),
                                toolsVersion: "5.2")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db).wait()
            try Build(version: v,
                      platform: .ios,
                      status: .ok,
                      swiftVersion: .v5_2).save(on: app.db).wait()
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
                       summary: "summary 1",
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo").create(on: app.db).wait()
        try Repository(package: p2,
                       summary: "summary 2",
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 owner: "foo",
                                                 authorName: "Foo",
                                                 collectionName: "Foo",
                                                 keywords: ["key", "word"],
                                                 overview: "overview")
            .wait()

        // validate
        assertSnapshot(matching: res, as: .json(encoder))
    }

    func test_includes_significant_versions_only() throws {
        // Ensure we only export significant versions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1147
        // setup
        Current.date = { Date(timeIntervalSince1970: 1610112345) }
        let p = try savePackage(on: app.db, "https://github.com/foo/1")
        try Repository(package: p,
                       summary: "summary",
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo").create(on: app.db).wait()
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
                                                 owner: "foo",
                                                 authorName: "Foo",
                                                 collectionName: "Foo",
                                                 keywords: ["key", "word"],
                                                 overview: "overview")
            .wait()

        // validate
        XCTAssertEqual(res.packages.flatMap { $0.versions.map({$0.version}) },
                       ["2.0.0-b1", "1.2.3"])
    }
}
