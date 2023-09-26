// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import XCTVapor


class SocialTests: AppTestCase {

    func test_versionUpdateMessage() throws {
        XCTAssertEqual(
            Social.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: "This is a test package",
                maxLength: Twitter.tweetMaxLength),
            """
            ⬆️ owner just released packageName v2.6.4 – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """
        )

        // no summary
        XCTAssertEqual(
            Social.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: nil,
                maxLength: Twitter.tweetMaxLength),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """
        )

        // empty summary
        XCTAssertEqual(
            Social.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: "",
                maxLength: Twitter.tweetMaxLength),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """
        )

        // whitespace summary
        XCTAssertEqual(
            Social.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: " \n",
                maxLength: Twitter.tweetMaxLength),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """
        )
    }

    func test_versionUpdateMessage_trimming() throws {
        let msg = Social.versionUpdateMessage(
            packageName: "packageName",
            repositoryOwnerName: "owner",
            url: "http://localhost:8080/owner/SuperAwesomePackage",
            version: .init(2, 6, 4),
            summary: String(repeating: "x", count: 280),
            maxLength: Twitter.tweetMaxLength
        )

        XCTAssertEqual(msg.count, 260)
        XCTAssertEqual(msg, """
            ⬆️ owner just released packageName v2.6.4 – xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx…

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """)
    }

    func test_newPackageMessage() throws {
        XCTAssertEqual(
            Social.newPackageMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                summary: "This is a test package",
                maxLength: Twitter.tweetMaxLength
            ),
            """
            📦 owner just added a new package, packageName – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_firehoseMessage_new_version() async throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .ok)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "owner",
                             summary: "This is a test package").save(on: app.db)
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try await version.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

        // MUT
        let res = Social.firehoseMessage(package: jpr,
                                         version: version,
                                         maxLength: Twitter.tweetMaxLength)

        // validate
        XCTAssertEqual(res, """
            ⬆️ owner just released MyPackage v1.2.3 – This is a test package

            http://localhost:8080/owner/repoName#releases
            """)
    }

    func test_firehoseMessage_new_package() async throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .new)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "owner",
                             summary: "This is a test package").save(on: app.db)
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try await version.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

        // MUT
        let res = Social.firehoseMessage(package: jpr,
                                         version: version,
                                         maxLength: Twitter.tweetMaxLength)

        // validate
        XCTAssertEqual(res, """
            📦 owner just added a new package, MyPackage – This is a test package

            http://localhost:8080/owner/repoName
            """)
    }

    func test_postToFirehose_only_release_and_preRelease() async throws {
        // ensure we only post about releases and pre-releases
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "repoOwner",
                             summary: "This is a test package").save(on: app.db)
        try await Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
            .save(on: app.db)
        try await Version(package: pkg,
                          commitDate: Date(timeIntervalSince1970: 0),
                          packageName: "MyPackage",
                          reference: .tag(2, 0, 0, "b1")).save(on: app.db)
        try await Version(package: pkg, packageName: "MyPackage", reference: .branch("main"))
            .save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)
        let versions = try await Analyze.updateLatestVersions(on: app.db, package: jpr)

        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        let posted = ActorIsolated(0)
        Current.twitterPost = { _, _ in await posted.increment() }
        Current.mastodonPost = { _, _ in await posted.increment() }

        // MUT
        try await Social.postToFirehose(client: app.client,
                                        package: jpr,
                                        versions: versions)

        // validate
        try await XCTAssertEqualAsync(await posted.value, 4)
    }

    func test_postToFirehose_only_latest() async throws {
        // ensure we only post about latest versions
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .ok)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "repoOwner",
                             summary: "This is a test package").save(on: app.db)
        try await Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
            .save(on: app.db)
        try await Version(package: pkg, packageName: "MyPackage", reference: .tag(2, 0, 0))
            .save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)
        let versions = try await Analyze.updateLatestVersions(on: app.db, package: jpr)

        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        let posted = ActorIsolated(0)
        Current.twitterPost = { _, msg in
            XCTAssertTrue(msg.contains("v2.0.0"))
            await posted.increment()
        }
        Current.mastodonPost = { _, msg in
            XCTAssertTrue(msg.contains("v2.0.0"))
            await posted.increment()
        }

        // MUT
        try await Social.postToFirehose(client: app.client,
                                         package: jpr,
                                         versions: versions)

        // validate
        try await XCTAssertEqualAsync(await posted.value, 2)
    }

}
