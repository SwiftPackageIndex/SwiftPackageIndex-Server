@testable import App

import XCTVapor
import SemanticVersion


class TwitterTests: AppTestCase {
    
    func test_firehoseMessage() throws {
        XCTAssertEqual(
            Twitter.firehoseMessage(
                repositoryOwner: "owner",
                repositoryName: "repoName",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: "This is a test package"),
            """
            owner just released repoName v2.6.4 – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )

        // no summary
        XCTAssertEqual(
            Twitter.firehoseMessage(
                repositoryOwner: "owner",
                repositoryName: "repoName",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: nil),
            """
            owner just released repoName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_firehoseMessage_trimming() throws {
        let msg = Twitter.firehoseMessage(
            repositoryOwner: "owner",
            repositoryName: "repoName",
            url: "http://localhost:8080/owner/SuperAwesomePackage",
            version: .init(2, 6, 4),
            summary: String(repeating: "x", count: 280)
        )

        XCTAssertEqual(msg.count, 260)
        XCTAssertEqual(msg, """
            owner just released repoName v2.6.4 – xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx…

            http://localhost:8080/owner/SuperAwesomePackage
            """)
    }

    func test_firehoseMessage_for_version() throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       summary: "This is a test package",
                       name: "repoName",
                       owner: "owner").save(on: app.db).wait()
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try version.save(on: app.db).wait()

        // MUT
        let res = try Twitter.firehoseMessage(db: app.db, for: version).wait()

        // validate
        XCTAssertEqual(res, """
        owner just released repoName v1.2.3 – This is a test package

        http://localhost:8080/owner/repoName
        """)
    }

    func test_onlyReleaseAndPreRelease() throws {
        // ensure we only tweet about releases and pre-releases
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       summary: "This is a test package",
                       name: "repoName",
                       owner: "repoOwner").save(on: app.db).wait()
        let v1 = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try v1.save(on: app.db).wait()
        let v2 = try Version(package: pkg, packageName: "MyPackage", reference: .tag(2, 0, 0, "b1"))
        try v2.save(on: app.db).wait()
        let v3 = try Version(package: pkg, packageName: "MyPackage", reference: .branch("main"))
        try v3.save(on: app.db).wait()
        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        var posted = 0
        Current.twitterPostTweet = { _, _ in
            posted += 1
            return self.app.eventLoopGroup.future()
        }

        // MUT
        try onNewVersions(client: app.client,
                          logger: app.logger,
                          transaction: app.db,
                          versions: [v1, v2, v3]).wait()

        // validate
        XCTAssertEqual(posted, 2)
    }

}
