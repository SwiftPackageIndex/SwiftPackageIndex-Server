@testable import App
import XCTest


class PackageCollectionTests: AppTestCase {

    func test_generate_basic() throws {
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
        XCTAssertEqual(res.name, "Foo")
        XCTAssertEqual(res.packages,[
                        .init(url: "1",
                              summary: "summary",
                              keywords: nil,
                              readmeURL: nil,
                              versions: [])
        ])
    }

}
