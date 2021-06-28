@testable import App

import XCTVapor
import SemanticVersion


class TwitterTests: AppTestCase {
    
    func test_versionUpdateMessage() throws {
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: "This is a test package"),
            """
            ⬆️ owner just released packageName v2.6.4 – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )

        // no summary
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: nil),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )

        // empty summary
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: ""),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )

        // whitespace summary
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: " \n"),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_versionUpdateMessage_trimming() throws {
        let msg = Twitter.versionUpdateMessage(
            packageName: "packageName",
            repositoryOwnerName: "owner",
            url: "http://localhost:8080/owner/SuperAwesomePackage",
            version: .init(2, 6, 4),
            summary: String(repeating: "x", count: 280)
        )

        XCTAssertEqual(msg.count, 260)
        XCTAssertEqual(msg, """
            ⬆️ owner just released packageName v2.6.4 – xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx…

            http://localhost:8080/owner/SuperAwesomePackage
            """)
    }

    func test_newPackageMessage() throws {
        XCTAssertEqual(
            Twitter.newPackageMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                summary: "This is a test package"),
            """
            📦 owner just added a new package, packageName – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_firehoseMessage_new_version() throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .ok)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "repoName",
                       owner: "owner",
                       summary: "This is a test package").save(on: app.db).wait()
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try version.save(on: app.db).wait()

        // MUT
        let res = try Twitter.firehoseMessage(db: app.db, for: version).wait()

        // validate
        XCTAssertEqual(res, """
            ⬆️ owner just released MyPackage v1.2.3 – This is a test package

            http://localhost:8080/owner/repoName
            """)
    }

    func test_firehoseMessage_new_package() throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .new)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "repoName",
                       owner: "owner",
                       summary: "This is a test package").save(on: app.db).wait()
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try version.save(on: app.db).wait()

        // MUT
        let res = try Twitter.firehoseMessage(db: app.db, for: version).wait()

        // validate
        XCTAssertEqual(res, """
            📦 owner just added a new package, MyPackage – This is a test package

            http://localhost:8080/owner/repoName
            """)
    }

    func test_postToFirehose_only_release_and_preRelease() throws {
        // ensure we only tweet about releases and pre-releases
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "repoName",
                       owner: "repoOwner",
                       summary: "This is a test package").save(on: app.db).wait()
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
        let pkg = Package(url: "1".asGithubUrl.url, status: .ok)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "repoName",
                       owner: "repoOwner",
                       summary: "This is a test package").save(on: app.db).wait()
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

    func test_endToEnd() async throws {
        // setup
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

        var tag = Reference.tag(1, 2, 3)
        let url = "https://github.com/foo/bar"
        Current.fetchMetadata = { _, pkg in self.future(.mock(for: pkg)) }
        Current.fetchPackageList = { _ in [url.url] }

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t2 }
        Current.git.getTags = { _ in [tag] }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }

        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                return #"{ "name": "Mock", "products": [], "targets": [] }"#
            }
            return ""
        }
        // run first two processing steps
        try await reconcile(client: app.client, database: app.db)
        try ingest(client: app.client, database: app.db, logger: app.logger, limit: 10).wait()

        // MUT - analyze, triggering the tweet
        try analyze(client: app.client,
                    database: app.db,
                    logger: app.logger,
                    threadPool: app.threadPool,
                    limit: 10).wait()
        do {
            let msg = try XCTUnwrap(message)
            XCTAssertTrue(msg.hasPrefix("📦 foo just added a new package, Mock"), "was \(msg)")
        }

        // run stages again to simulate the cycle...
        message = nil
        try await reconcile(client: app.client, database: app.db)
        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime) }
        try ingest(client: app.client, database: app.db, logger: app.logger, limit: 10).wait()

        // MUT - analyze, triggering tweets if any
        try analyze(client: app.client,
                    database: app.db,
                    logger: app.logger,
                    threadPool: app.threadPool,
                    limit: 10).wait()

        // validate - there are no new tweets to send
        XCTAssertNil(message)

        // Now simulate receiving a package update: version 2.0.0
        tag = .tag(2, 0, 0)
        // fast forward our clock by the deadtime interval again (*2) and re-ingest
        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime * 2) }
        try ingest(client: app.client, database: app.db, logger: app.logger, limit: 10).wait()

        // MUT - analyze again
        try analyze(client: app.client,
                    database: app.db,
                    logger: app.logger,
                    threadPool: app.threadPool,
                    limit: 10).wait()

        // validate
        let msg = try XCTUnwrap(message)
        XCTAssertTrue(msg.hasPrefix("⬆️ foo just released Mock v2.0.0"), "was: \(msg)")
    }

    func test_allowTwitterPosts_switch() throws {
        // test ALLOW_TWITTER_POSTS environment variable
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       name: "repoName",
                       owner: "repoOwner",
                       summary: "This is a test package").save(on: app.db).wait()
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
