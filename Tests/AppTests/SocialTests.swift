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
import SnapshotTesting
import InlineSnapshotTesting
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
                maxLength: Social.postMaxLength),
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
                maxLength: Social.postMaxLength),
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
                maxLength: Social.postMaxLength),
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
                maxLength: Social.postMaxLength),
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
            summary: String(repeating: "x", count: 500),
            maxLength: Social.postMaxLength
        )

        XCTAssertEqual(msg.count, 490)
        XCTAssertEqual(msg, """
            ⬆️ owner just released packageName v2.6.4 – xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx…

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
                maxLength: Social.postMaxLength
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
                                         maxLength: Social.postMaxLength)

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
                                         maxLength: Social.postMaxLength)

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

        let posted = ActorIsolated(0)
        Current.mastodonPost = { _, _ in await posted.increment() }

        // MUT
        try await Social.postToFirehose(client: app.client,
                                        package: jpr,
                                        versions: versions)

        // validate
        try await XCTAssertEqualAsync(await posted.value, 2)
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

        let posted = ActorIsolated(0)
        Current.mastodonPost = { _, msg in
            XCTAssertTrue(msg.contains("v2.0.0"))
            await posted.increment()
        }

        // MUT
        try await Social.postToFirehose(client: app.client,
                                         package: jpr,
                                         versions: versions)

        // validate
        try await XCTAssertEqualAsync(await posted.value, 1)
    }

    func test_urlEncoding() async throws {
        // setup
        Current.mastodonCredentials = { .init(accessToken: "fakeToken") }
        let message = Social.versionUpdateMessage(
            packageName: "packageName",
            repositoryOwnerName: "owner",
            url: "http://localhost:8080/owner/SuperAwesomePackage",
            version: .init(2, 6, 4),
            summary: nil,
            maxLength: Social.postMaxLength
        )

        // MUT
        try? await Mastodon.post(client: app.client, message: message) { encoded in
            assertInlineSnapshot(of: encoded, as: .lines) {
                """
                https://mas.to/api/v1/statuses?status=%E2%AC%86%EF%B8%8F%20owner%20just%20released%20packageName%20v2.6.4%0A%0Ahttp%3A%2F%2Flocalhost%3A8080%2Fowner%2FSuperAwesomePackage%23releases
                """
            }
        }
    }

}

extension SnapshotTesting.Snapshotting: @unchecked Swift.Sendable {}
extension SnapshotTesting.Diffing: @unchecked Swift.Sendable {}
