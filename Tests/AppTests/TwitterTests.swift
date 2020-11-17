@testable import App

import XCTVapor
import SemanticVersion


class TwitterTests: AppTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let package = Package(id: UUID(), url: "https://github.com/user/package.git")
        
        let repository = try Repository(id: UUID(),
                                        package: package,
                                        summary: "This is a test package",
                                        defaultBranch: "main",
                                        license: .mit,
                                        name: "SuperAwesomePackage",
                                        owner: "owner",
                                        stars: 3,
                                        forks: 2)
        let version = try Version(id: UUID(),
                                  package: package,
                                  packageName: "Test package",
                                  reference: .tag(SemanticVersion(2, 6, 4), ""))
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
    
    func test_buildPost() throws {
        let package = try Package.query(on: app.db, owner: "owner", repository: "SuperAwesomePackage").wait()
        let output = Twitter.buildFirehosePost(package: package)
        XCTAssertEqual(output, """
        SuperAwesomePackage just released v2.6.4 - This is a test package
        
        http://localhost:8080/owner/SuperAwesomePackage
        """)
    }
    
}
