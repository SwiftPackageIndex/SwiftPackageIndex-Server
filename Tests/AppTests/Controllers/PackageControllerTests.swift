@testable import App

import Vapor
import XCTest

class PackageControllerTests: AppTestCase {
    
    let testPackageId: UUID = UUID()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let package = Package(id: testPackageId, url: "https://github.com/user/package.git")
        let repository = try Repository(id: UUID(),
                                        package: package,
                                        summary: "This is a test package",
                                        defaultBranch: "main",
                                        license: .mit,
                                        name: "package",
                                        owner: "owner",
                                        stars: 3,
                                        forks: 2)
        let version = try Version(id: UUID(),
                                  package: package,
                                  reference: .branch("main"),
                                  packageName: "Test package")
        let product = try Product(id: UUID(), version: version, type: .library, name: "Library")
        
        try package.save(on: app.db).wait()
        try repository.save(on: app.db).wait()
        try version.save(on: app.db).wait()
        try product.save(on: app.db).wait()
    }
    
    func test_index() throws {
        try app.test(.GET, "/packages") { response in
            XCTAssertEqual(response.status, .seeOther)
        }
    }
    
    func test_show_owner_repository() throws {
        try app.test(.GET, "/owner/package") { response in
            XCTAssertEqual(response.status, .ok)
        }
    }
    
}
