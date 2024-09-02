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

import SQLKit
import XCTVapor


final class RepositoryTests: AppTestCase {

    func test_save() async throws {
        let pkg = Package(id: UUID(), url: "1")
        try await pkg.save(on: app.db)
        let repo = try Repository(id: UUID(),
                                  package: pkg,
                                  authors: PackageAuthors(authors: [
                                    .init(name: "Foo"),
                                    .init(name: "Bar")], numberOfContributors: 0),
                                  commitCount: 123,
                                  defaultBranch: "branch",
                                  firstCommitDate: Date(timeIntervalSince1970: 0),
                                  forks: 17,
                                  forkedFrom: nil,
                                  isArchived: true,
                                  keywords: ["foo", "bar"],
                                  lastCommitDate: Date(timeIntervalSince1970: 1),
                                  lastIssueClosedAt: Date(timeIntervalSince1970: 2),
                                  lastPullRequestClosedAt: Date(timeIntervalSince1970: 3),
                                  license: .mit,
                                  licenseUrl: "https://github.com/foo/bar/blob/main/LICENSE",
                                  openIssues: 3,
                                  openPullRequests: 4,
                                  readmeHtmlUrl: "https://github.com/foo/bar/blob/main/README.md",
                                  releases: [
                                    .init(description: "a release",
                                          isDraft: false,
                                          publishedAt: Date(timeIntervalSince1970: 1),
                                          tagName: "1.2.3",
                                          url: "https://example.com/release/1.2.3")
                                  ],
                                  s3Readme: .cached(s3ObjectUrl: "objectUrl", githubEtag: "etag"),
                                  stars: 42,
                                  summary: "desc")

        try await repo.save(on: app.db)

        do {
            let r = try await XCTUnwrapAsync(try await Repository.find(repo.id, on: app.db))
            XCTAssertEqual(r.$package.id, pkg.id)
            XCTAssertEqual(r.authors,
                           PackageAuthors(authors: [ .init(name: "Foo"), .init(name: "Bar")],
                                          numberOfContributors: 0))
            XCTAssertEqual(r.commitCount, 123)
            XCTAssertEqual(r.defaultBranch, "branch")
            XCTAssertEqual(r.firstCommitDate, Date(timeIntervalSince1970: 0))
            XCTAssertEqual(r.forks, 17)
            XCTAssertEqual(r.forkedFrom, nil)
            XCTAssertEqual(r.isArchived, true)
            XCTAssertEqual(r.keywords, ["foo", "bar"])
            XCTAssertEqual(r.lastCommitDate, Date(timeIntervalSince1970: 1))
            XCTAssertEqual(r.lastIssueClosedAt, Date(timeIntervalSince1970: 2))
            XCTAssertEqual(r.lastPullRequestClosedAt, Date(timeIntervalSince1970: 3))
            XCTAssertEqual(r.license, .mit)
            XCTAssertEqual(r.licenseUrl, "https://github.com/foo/bar/blob/main/LICENSE")
            XCTAssertEqual(r.openIssues, 3)
            XCTAssertEqual(r.openPullRequests, 4)
            XCTAssertEqual(r.s3Readme, .cached(s3ObjectUrl: "objectUrl", githubEtag: "etag"))
            XCTAssertEqual(r.readmeHtmlUrl, "https://github.com/foo/bar/blob/main/README.md")
            XCTAssertEqual(r.releases, [
                .init(description: "a release",
                      isDraft: false,
                      publishedAt: Date(timeIntervalSince1970: 1),
                      tagName: "1.2.3",
                      url: "https://example.com/release/1.2.3")
            ])
            XCTAssertEqual(r.stars, 42)
            XCTAssertEqual(r.summary, "desc")
        }
    }

    func test_generated_lastActivityAt_lastCommitDate() async throws {
        let pkg = Package(url: "p1")
        try await pkg.save(on: app.db)

        let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
        let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

        let repo = try Repository(package: pkg)
        repo.lastCommitDate = moreRecentDate
        repo.lastIssueClosedAt = oldestDate
        repo.lastPullRequestClosedAt = oldestDate
        try await repo.save(on: app.db)

        let fetchedRepo = try await XCTUnwrapAsync(try await Repository.find(repo.id, on: app.db))
        XCTAssertEqual(fetchedRepo.lastActivityAt, moreRecentDate)
    }

    func test_generated_lastActivityAt_lastIssueClosedAt() async throws {
        let pkg = Package(url: "p1")
        try await pkg.save(on: app.db)

        let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
        let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

        let repo = try Repository(package: pkg)
        repo.lastCommitDate = oldestDate
        repo.lastIssueClosedAt = moreRecentDate
        repo.lastPullRequestClosedAt = oldestDate
        try await repo.save(on: app.db)

        let fetchedRepo = try await XCTUnwrapAsync(try await Repository.find(repo.id, on: app.db))
        XCTAssertEqual(fetchedRepo.lastActivityAt, moreRecentDate)
    }

    func test_generated_lastActivityAt_lastPullRequestClosedAt() async throws {
        let pkg = Package(url: "p1")
        try await pkg.save(on: app.db)

        let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
        let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

        let repo = try Repository(package: pkg)
        repo.lastCommitDate = oldestDate
        repo.lastIssueClosedAt = oldestDate
        repo.lastPullRequestClosedAt = moreRecentDate
        try await repo.save(on: app.db)

        let fetchedRepo = try await XCTUnwrapAsync(try await Repository.find(repo.id, on: app.db))
        XCTAssertEqual(fetchedRepo.lastActivityAt, moreRecentDate)
    }

    func test_generated_lastActivityAt_nullValues() async throws {
        let pkg = Package(url: "p1")
        try await pkg.save(on: app.db)

        let date = Date(timeIntervalSinceReferenceDate: 0)

        let repo = try Repository(package: pkg)
        repo.lastCommitDate = date
        repo.lastIssueClosedAt = nil
        repo.lastPullRequestClosedAt = nil
        try await repo.save(on: app.db)

        let fetchedRepo = try await XCTUnwrapAsync(try await Repository.find(repo.id, on: app.db))
        XCTAssertEqual(fetchedRepo.lastActivityAt, date)
    }

    func test_package_relationship() async throws {
        let pkg = Package(url: "p1")
        try await pkg.save(on: app.db)
        let repo = try Repository(package: pkg)
        try await repo.save(on: app.db)
        // test some ways to resolve the relationship
        XCTAssertEqual(repo.$package.id, pkg.id)
        let db = app.db
        try await XCTAssertEqualAsync(try await repo.$package.get(on: db).url, "p1")

        // ensure one-to-one is in place
        do {
            let repo = try Repository(package: pkg)
            do {
                try await repo.save(on: app.db)
                XCTFail("Expected error")
            } catch { }
            try await XCTAssertEqualAsync(try await Repository.query(on: db).all().count, 1)
        }
    }

    func test_delete_cascade() async throws {
        // delete package must delete repository
        let pkg = Package(id: UUID(), url: "1")
        let repo = try Repository(id: UUID(), package: pkg)
        try await pkg.save(on: app.db)
        try await repo.save(on: app.db)

        let db = app.db
        try await XCTAssertEqualAsync(try await Package.query(on: db).count(), 1)
        try await XCTAssertEqualAsync(try await Repository.query(on: db).count(), 1)

        // MUT
        try await pkg.delete(on: app.db)

        // version and product should be deleted
        try await XCTAssertEqualAsync(try await Package.query(on: db).count(), 0)
        try await XCTAssertEqualAsync(try await Repository.query(on: db).count(), 0)
    }

    func test_uniqueOwnerRepository() async throws {
        // Ensure owner/repository is unique, testing various combinations with
        // matching/non-matching case
        let p1 = try await savePackage(on: app.db, "1")
        try await Repository(id: UUID(), package: p1, name: "bar", owner: "foo").save(on: app.db)
        let p2 = try await savePackage(on: app.db, "2")
        let db = app.db

        do {
            // MUT - identical
            try await Repository(id: UUID(), package: p2, name: "bar", owner: "foo").save(on: app.db)
            XCTFail("Expected error")
        } catch {
            XCTAssert(String(reflecting: error).contains(
                #"duplicate key value violates unique constraint "idx_repositories_owner_name""#),
                      "was: \(error.localizedDescription)"
            )
            try await XCTAssertEqualAsync(try await Repository.query(on: db).all().count, 1)
        }

        do {
            // MUT - diffrent case repository
            try await Repository(id: UUID(), package: p2, name: "Bar", owner: "foo").save(on: app.db)
            XCTFail("Expected error")
        } catch {
            XCTAssert(String(reflecting: error).contains(
                #"duplicate key value violates unique constraint "idx_repositories_owner_name""#),
                      "was: \(error.localizedDescription)"
            )
            try await XCTAssertEqualAsync(try await Repository.query(on: db).all().count, 1)
        }

        do {
            // MUT - diffrent case owner
            try await Repository(id: UUID(), package: p2, name: "bar", owner: "Foo").save(on: app.db)
            XCTFail("Expected error")
        } catch {
            XCTAssert(String(reflecting: error).contains(
                #"duplicate key value violates unique constraint "idx_repositories_owner_name""#),
                      "was: \(error.localizedDescription)"
            )
            try await XCTAssertEqualAsync(try await Repository.query(on: db).all().count, 1)
        }
    }

    func test_name_index() async throws {
        let db = try XCTUnwrap(app.db as? SQLDatabase)
        // Quick way to check index exists - this will throw
        //   "server: index "idx_repositories_name" does not exist (DropErrorMsgNonExistent)"
        // if it doesn't
        try await db.raw("DROP INDEX idx_repositories_name").run()
        // Recreate index or else the revert in the next tests setUp is going to fail
        try await db.raw("CREATE INDEX idx_repositories_name ON repositories USING gin (name gin_trgm_ops)").run()
    }
    
    func test_S3Readme_needsUpdate() {
        XCTAssertTrue(S3Readme.error("").needsUpdate(upstreamEtag: "etag"))
        XCTAssertFalse(S3Readme.cached(s3ObjectUrl: "", githubEtag: "old etag").needsUpdate(upstreamEtag: "old etag"))
        XCTAssertTrue(S3Readme.cached(s3ObjectUrl: "", githubEtag: "old etag").needsUpdate(upstreamEtag: "new etag"))
    }

}
