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
        XCTAssertEqual(
            Twitter.firehostPost(
                packageName: "SuperAwesomePackage",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: "This is a test package"),
            """
            SuperAwesomePackage just released version 2.6.4 – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )

        // no summary
        XCTAssertEqual(
            Twitter.firehostPost(
                packageName: "SuperAwesomePackage",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: nil),
            """
            SuperAwesomePackage just released version 2.6.4

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_postToFirehose() throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, summary: "This is a test package").save(on: app.db).wait()
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try version.save(on: app.db).wait()

        // MUT
        let res = try Twitter.firehostPost(db: app.db, for: version).wait()

        // validate
        XCTAssertEqual(res, """
        MyPackage just released version 1.2.3 – This is a test package

        https://github.com/foo/1
        """)
    }
    
}
