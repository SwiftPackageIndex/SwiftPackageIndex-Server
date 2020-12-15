@testable import App
import XCTest


class PackageCollectionTests: XCTestCase {

    func test_generate_basic() throws {
        let res = PackageCollection.generate(name: "Foo",
                                             overview: "overview",
                                             keywords: ["key", "word"],
                                             packageURLs: [],
                                             createdAt: Date(),
                                             createdBy: .init(name: "Foo", url: nil))
        XCTAssertEqual(res.name, "Foo")
        XCTAssertEqual(res.packages.count, 0)
    }

}
