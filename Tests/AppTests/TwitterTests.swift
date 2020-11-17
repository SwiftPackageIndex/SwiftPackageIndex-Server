@testable import App

import XCTVapor
import SemanticVersion


class TwitterTests: AppTestCase {
    
    func test_buildPost() throws {
        XCTAssertEqual(
            Twitter.firehostPost(
                repositoryName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: "This is a test package"),
            """
            owner just released version 2.6.4 – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )

        // no summary
        XCTAssertEqual(
            Twitter.firehostPost(
                repositoryName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: nil),
            """
            owner just released version 2.6.4

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_postToFirehose() throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       summary: "This is a test package",
                       name: "owner").save(on: app.db).wait()
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try version.save(on: app.db).wait()

        // MUT
        let res = try Twitter.firehostPost(db: app.db, for: version).wait()

        // validate
        XCTAssertEqual(res, """
        owner just released version 1.2.3 – This is a test package

        https://github.com/foo/1
        """)
    }
    
}
