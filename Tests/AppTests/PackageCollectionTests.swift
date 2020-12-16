@testable import App
import XCTest


class PackageCollectionTests: AppTestCase {

    func test_generate_from_urls() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, summary: "summary").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 name: "Foo",
                                                 overview: "overview",
                                                 keywords: ["key", "word"],
                                                 packageURLs: ["1"],
                                                 createdBy: .init(name: "Foo", url: nil)).wait()

        // validate
        XCTAssertEqual(res.name, "Foo")
        XCTAssertEqual(res.packages,[
                        .init(url: "1",
                              summary: "summary",
                              keywords: nil,
                              readmeURL: nil,
                              versions: [])
        ])
    }

    func test_generate_for_owner() throws {
        // setup
        // first package
        let p1 = try savePackage(on: app.db, "https://github.com/foo/1")
        do {
            let v = try Version(id: UUID(),
                                package: p1,
                                packageName: "P1-main",
                                reference: .branch("main"))
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library, name: "P1Lib")
                .save(on: app.db).wait()
        }
        do {
            let v = try Version(id: UUID(),
                                package: p1,
                                packageName: "P1-tag",
                                reference: .tag(1, 2, 3))
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library, name: "P1Lib")
                .save(on: app.db).wait()
        }
        do {
            let v = try Version(id: UUID(),
                                package: p1,
                                packageName: "P1-tag",
                                reference: .tag(2, 0, 0))
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library, name: "P1Lib")
                .save(on: app.db).wait()
        }
        // second package
        let p2 = try savePackage(on: app.db, "https://github.com/foo/2")
        do {
            let v = try Version(id: UUID(),
                                package: p2,
                                packageName: "P2-main",
                                reference: .branch("main"))
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library, name: "P1Lib")
                .save(on: app.db).wait()
        }
        do {
            let v = try Version(id: UUID(),
                                package: p2,
                                packageName: "P2-tag",
                                reference: .tag(1, 2, 3))
            try v.save(on: app.db).wait()
            try Product(version: v, type: .library, name: "P1Lib")
                .save(on: app.db).wait()
        }
        // unrelated package
        _ = try savePackage(on: app.db, "https://github.com/bar/1")
        try Repository(package: p1,
                       summary: "summary 1",
                       defaultBranch: "main",
                       owner: "foo").create(on: app.db).wait()
        try Repository(package: p2,
                       summary: "summary 2",
                       defaultBranch: "main",
                       owner: "foo").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 name: "Foo",
                                                 overview: "overview",
                                                 keywords: ["key", "word"],
                                                 owner: "foo",
                                                 createdBy: .init(name: "Foo", url: nil)).wait()

        // validate

        // FIXME: use snapshot test (easier diffs)
        XCTAssertEqual(res.name, "Foo")
        XCTAssertEqual(res.packages, [
                        .init(url: "https://github.com/foo/1",
                              summary: "summary 1",
                              keywords: nil,
                              readmeURL: nil,
                              versions: [
                                .init(version: .init(2, 0, 0),
                                      packageName: "P1-tag",
                                      targets: [],
                                      products: []),
                                .init(version: .init(1, 2, 3),
                                      packageName: "P1-tag",
                                      targets: [],
                                      products: [])
                              ]),
                        .init(url: "https://github.com/foo/2",
                              summary: "summary 2",
                              keywords: nil,
                              readmeURL: nil,
                              versions: [
                                .init(version: .init(1, 2, 3),
                                                 packageName: "P2-tag",
                                                 targets: [],
                                                 products: [])
                              ])
        ])
    }

}
