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
        let p1 = try savePackage(on: app.db, "https://github.com/foo/1")
        let p2 = try savePackage(on: app.db, "https://github.com/foo/2")
        _ = try savePackage(on: app.db, "https://github.com/bar/1")
        try Repository(package: p1, summary: "summary 1", owner: "foo").create(on: app.db).wait()
        try Repository(package: p2, summary: "summary 2", owner: "foo").create(on: app.db).wait()

        // MUT
        let res = try PackageCollection.generate(db: self.app.db,
                                                 name: "Foo",
                                                 overview: "overview",
                                                 keywords: ["key", "word"],
                                                 owner: "foo",
                                                 createdBy: .init(name: "Foo", url: nil)).wait()

        // validate
        XCTAssertEqual(res.name, "Foo")
        XCTAssertEqual(res.packages,[
                        .init(url: "https://github.com/foo/1",
                              summary: "summary 1",
                              keywords: nil,
                              readmeURL: nil,
                              versions: []),
                        .init(url: "https://github.com/foo/2",
                              summary: "summary 2",
                              keywords: nil,
                              readmeURL: nil,
                              versions: [])
        ])
    }

}
