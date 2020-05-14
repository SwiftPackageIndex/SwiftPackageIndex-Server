@testable import App

import Vapor
import XCTest

class PackageControllerTests: AppTestCase {

    let testPackageId: UUID = UUID()

    override func setUpWithError() throws {
        try super.setUpWithError()

        let package = Package(id: testPackageId, url: "https://github.com/user/package.git", status: .none)
        let version = try Version(id: UUID(), package: package)
        let product = try Product(id: UUID(), version: version, type: .library, name: "Library")

        try package.save(on: app.db).wait()
        try version.save(on: app.db).wait()
        try product.save(on: app.db).wait()
    }

    func test_index() throws {
        try app.test(.GET, "/packages") { response in
            XCTAssertEqual(response.status, .seeOther)
        }
    }

    func test_show() throws {
        let _ = try Package.find(testPackageId, on: app.db).wait()!

        try app.test(.GET, "/packages/\(testPackageId)") { response in
            XCTAssertEqual(response.status, .ok)
        }
    }

}
