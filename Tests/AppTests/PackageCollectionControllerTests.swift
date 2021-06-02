@testable import App
import SnapshotTesting
import XCTVapor


class PackageCollectionControllerTests: AppTestCase {

    func test_owner_request() throws {
        // setup
        Current.date = { .t0 }
        let p = try savePackage(on: app.db, "https://github.com/foo/1")
        do {
            let v = try Version(id: UUID(),
                                package: p,
                                packageName: "P1-main",
                                reference: .branch("main"),
                                toolsVersion: "5.0")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib")
                .save(on: app.db).wait()
        }
        do {
            let v = try Version(id: UUID(),
                                package: p,
                                packageName: "P1-tag",
                                reference: .tag(1, 2, 3),
                                toolsVersion: "5.1")
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library(.automatic), name: "P1Lib", targets: ["t1"])
                .save(on: app.db).wait()
            try Build(version: v,
                      platform: .ios,
                      status: .ok,
                      swiftVersion: .v5_2).save(on: app.db).wait()
            try Target(version: v, name: "t1").save(on: app.db).wait()
        }
        try Repository(package: p,
                       summary: "summary 1",
                       defaultBranch: "main",
                       license: .mit,
                       licenseUrl: "https://foo/mit",
                       owner: "foo").create(on: app.db).wait()

        // MUT
        try app.test(
            .GET,
            "foo/collection.json",
            afterResponse: { res in
                // validation
                XCTAssertEqual(res.status, .ok)
                let json = try res.content.decode(PackageCollection.self)
                assertSnapshot(matching: json, as: .json(encoder))
            })
    }

    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

}
