@testable import App

import Vapor
import XCTest

class AuthorControllerTests: AppTestCase {
    
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
                                  packageName: "Test package",
                                  reference: .branch("main"))
        let product = try Product(id: UUID(), version: version, type: .library, name: "Library")
        
        try package.save(on: app.db).wait()
        try repository.save(on: app.db).wait()
        try version.save(on: app.db).wait()
        try product.save(on: app.db).wait()

        // re-load repository relationship (required for updateLatestVersions)
        try package.$repositories.load(on: app.db).wait()
        // update versions
        _ = try updateLatestVersions(on: app.db, package: package).wait()
    }

    func test_show_owner() throws {
        try app.test(.GET, "/owner", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }

    func test_show_owner_empty() throws {
        try app.test(.GET, "/fake-owner", afterResponse: { response in
            XCTAssertEqual(response.status, .notFound)
        })
    }

}
