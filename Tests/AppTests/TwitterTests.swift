@testable import App

import XCTVapor
import SemanticVersion


class TwitterTests: AppTestCase {
    
    func test_versionUpdateMessage() throws {
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
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
            Twitter.versionUpdateMessage(
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

    func test_versionUpdateMessage_trimming() throws {
        let msg = Twitter.versionUpdateMessage(
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

    func test_newPackageMessage() throws {
        XCTAssertEqual(
            Twitter.newPackageMessage(
                packageName: "packageName",
                repositoryOwner: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                summary: "This is a test package"),
            """
            New package: packageName by owner – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_firehoseMessage_new_version() throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, processingStage: .analysis)
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

    func test_firehoseMessage_new_package() throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, processingStage: .reconciliation)
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
        New package: MyPackage by owner – This is a test package

        http://localhost:8080/owner/repoName
        """)
    }

    func test_postToFirehose_only_release_and_preRelease() throws {
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
        let v2 = try Version(package: pkg,
                             commitDate: Date(timeIntervalSince1970: 0),
                             packageName: "MyPackage",
                             reference: .tag(2, 0, 0, "b1"))
        try v2.save(on: app.db).wait()
        let v3 = try Version(package: pkg, packageName: "MyPackage", reference: .branch("main"))
        try v3.save(on: app.db).wait()
        try updateLatestVersions(on: app.db, package: pkg).wait()

        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        var posted = 0
        Current.twitterPostTweet = { _, _ in
            posted += 1
            return self.app.eventLoopGroup.future()
        }

        // MUT
        try Twitter.postToFirehose(client: app.client,
                                   database: app.db,
                                   package: pkg,
                                   versions: [v1, v2, v3]).wait()

        // validate
        XCTAssertEqual(posted, 2)
    }

    func test_postToFirehose_only_latest() throws {
        // ensure we only tweet about latest versions
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, processingStage: .ingestion)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       summary: "This is a test package",
                       name: "repoName",
                       owner: "repoOwner").save(on: app.db).wait()
        let v1 = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try v1.save(on: app.db).wait()
        let v2 = try Version(package: pkg, packageName: "MyPackage", reference: .tag(2, 0, 0))
        try v2.save(on: app.db).wait()
        try updateLatestVersions(on: app.db, package: pkg).wait()

        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        var message: String?
        Current.twitterPostTweet = { _, msg in
            if message == nil {
                message = msg
            } else {
                XCTFail("message must only be set once")
            }
            return self.app.eventLoopGroup.future()
        }

        // MUT
        try Twitter.postToFirehose(client: app.client,
                                   database: app.db,
                                   package: pkg,
                                   versions: [v1, v2]).wait()

        // validate
        XCTAssertTrue(message?.contains("v2.0.0") ?? false)
    }

    func test_allowTwitterPosts_switch() throws {
        // test ALLOW_TWITTER_POSTS environment variable
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       summary: "This is a test package",
                       name: "repoName",
                       owner: "repoOwner").save(on: app.db).wait()
        let v = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try v.save(on: app.db).wait()
        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        var posted = 0
        Current.twitterPostTweet = { _, _ in
            posted += 1
            return self.app.eventLoopGroup.future()
        }

        // MUT & validate - disallow if set to false
        Current.allowTwitterPosts = { false }
        XCTAssertThrowsError(
            try Twitter.postToFirehose(client: app.client, database: app.db, version: v).wait()
        ) {
            XCTAssertTrue($0.localizedDescription.contains("App.Twitter.Error error 3"))
        }
        XCTAssertEqual(posted, 0)

        // MUT & validate - allow if set to true
        Current.allowTwitterPosts = { true }
        try Twitter.postToFirehose(client: app.client, database: app.db, version: v).wait()
        XCTAssertEqual(posted, 1)
    }

}
