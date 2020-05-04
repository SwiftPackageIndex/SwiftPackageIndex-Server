@testable import App

import XCTVapor


class ProductTests: AppTestCase {

    func test_Product_save() throws {
        let pkg = Package(id: UUID(), url: "1".url, status: .none)
        let ver = try Version(id: UUID(), package: pkg)
        let prod = try Product(id: UUID(), version: ver, type: .library, name: "p1")
        try pkg.save(on: app.db).wait()
        try ver.save(on: app.db).wait()
        try prod.save(on: app.db).wait()
        do {
            let p = try XCTUnwrap(Product.find(prod.id, on: app.db).wait())
            XCTAssertEqual(p.$version.id, ver.id)
            XCTAssertEqual(p.type, .library)
            XCTAssertEqual(p.name, "p1")
        }
    }

    func test_delete_cascade() throws {
        // delete version must delete products
    }
}
