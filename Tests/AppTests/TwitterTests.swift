@testable import App

import XCTVapor
import SemanticVersion


class TwitterTests: AppTestCase {
    
    func test_versionUpdateMessage() throws {
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwner: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: "This is a test package"),
            """
            owner just released packageName v2.6.4 – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )

        // no summary
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwner: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: nil),
            """
            owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_versionUpdateMessage_trimming() throws {
        let msg = Twitter.versionUpdateMessage(
            packageName: "packageName",
            repositoryOwner: "owner",
            url: "http://localhost:8080/owner/SuperAwesomePackage",
            version: .init(2, 6, 4),
            summary: String(repeating: "x", count: 280)
        )

        XCTAssertEqual(msg.count, 260)
        XCTAssertEqual(msg, """
            owner just released packageName v2.6.4 – xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx…

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
        let pkg = Package(url: "1".asGithubUrl.url, status: .ok)
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
        owner just released MyPackage v1.2.3 – This is a test package

        http://localhost:8080/owner/repoName
        """)
    }

    func test_firehoseMessage_new_package() throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .new)
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
        let pkg = Package(url: "1".asGithubUrl.url, status: .ok)
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

    func test_endToEnd() throws {
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

        var tag = "1.2.3"
        let url = "https://github.com/foo/bar"
        Current.fetchMetadata = { _, pkg in self.future(.mock(for: pkg)) }
        Current.fetchPackageList = { _ in self.future([url.url]) }
        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                return #"{ "name": "Mock", "products": [] }"#
            }
            if cmd.string == "git tag" {
                return tag }
            if cmd.string.hasPrefix(#"git log -n1 --format=format:"%H-%ct""#) { return "sha-0" }
            if cmd.string == "git rev-list --count HEAD" { return "12" }
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }
            return ""
        }
        // run first two processing steps
        try reconcile(client: app.client, database: app.db).wait()
        try ingest(application: app, limit: 10).wait()

        // MUT - analyze, triggering the tweet
        try analyze(application: app, limit: 10).wait()
        do {
            let msg = try XCTUnwrap(message)
            XCTAssertTrue(msg.hasPrefix("New package: Mock by foo"), "was \(msg)")
        }

        // run stages again to simulate the cycle...
        message = nil
        try reconcile(client: app.client, database: app.db).wait()
        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime) }
        try ingest(application: app, limit: 10).wait()

        // MUT - analyze, triggering tweets if any
        try analyze(application: app, limit: 10).wait()

        // validate - there are no new tweets to send
        XCTAssertNil(message)

        // Now simulate receiving a package update: version 2.0.0
        tag = "2.0.0"
        // fast forward our clock by the deadtime interval again (*2) and re-ingest
        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime * 2) }
        try ingest(application: app, limit: 10).wait()

        // MUT - analyze again
        try analyze(application: app, limit: 10).wait()

        // validate
        let msg = try XCTUnwrap(message)
        XCTAssertTrue(msg.hasPrefix("foo just released Mock v2.0.0"), "was: \(msg)")
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
