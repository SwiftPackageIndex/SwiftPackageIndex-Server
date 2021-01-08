@testable import App
import SnapshotTesting
import XCTest


class PackageCollectionTests: AppTestCase {

    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func test_Package_init() throws {
        // Tests PackageCollection.Package initialisation from a App.Package
        // TODO
    }

    func test_generate_from_urls() throws {
        // setup
        Current.date = { Date(timeIntervalSince1970: 1610112345) }
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, summary: "summary").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 name: "Foo",
                                                 overview: "overview",
                                                 keywords: ["key", "word"],
                                                 packageURLs: ["1"],
                                                 generatedBy: .init(name: "Foo", url: nil)).wait()

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
                                                 generatedBy: .init(name: "Foo", url: nil)).wait()

        // validate
        assertSnapshot(matching: res, as: .json(encoder))
    }

}
