// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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
    
    func test_save() throws {
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        let repo = try Repository(id: UUID(),
                                  package: pkg,
                                  authors: PackageAuthors(authors: [
                                    .init(name: "Foo", url: "fooUrl"),
                                    .init(name: "Bar", url: "barUrl")], numberOfContributors: 0),
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
                                  readmeUrl: "https://raw.githubusercontent.com/foo/bar/main/README.md",
                                  readmeHtmlUrl: "https://github.com/foo/bar/blob/main/README.md",
                                  releases: [
                                    .init(description: "a release",
                                          isDraft: false,
                                          publishedAt: Date(timeIntervalSince1970: 1),
                                          tagName: "1.2.3",
                                          url: "https://example.com/release/1.2.3")
                                  ],
                                  stars: 42,
                                  summary: "desc")
        
        try repo.save(on: app.db).wait()
        
        do {
            let r = try XCTUnwrap(Repository.find(repo.id, on: app.db).wait())
            XCTAssertEqual(r.$package.id, pkg.id)
            XCTAssertEqual(r.authors,
                           PackageAuthors(authors: [ .init(name: "Foo", url: "fooUrl"), .init(name: "Bar", url: "barUrl")],
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
            XCTAssertEqual(r.readmeUrl, "https://raw.githubusercontent.com/foo/bar/main/README.md")
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

    func test_generated_lastActivityAt_lastCommitDate() throws {
        let pkg = Package(url: "p1")
        try pkg.save(on: app.db).wait()

        let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
        let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

        let repo = try Repository(package: pkg)
        repo.lastCommitDate = moreRecentDate
        repo.lastIssueClosedAt = oldestDate
        repo.lastPullRequestClosedAt = oldestDate
        try repo.save(on: app.db).wait()

        let fetchedRepo = try XCTUnwrap(Repository.find(repo.id, on: app.db).wait())
        XCTAssertEqual(fetchedRepo.lastActivityAt, moreRecentDate)
    }

    func test_generated_lastActivityAt_lastIssueClosedAt() throws {
        let pkg = Package(url: "p1")
        try pkg.save(on: app.db).wait()

        let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
        let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

        let repo = try Repository(package: pkg)
        repo.lastCommitDate = oldestDate
        repo.lastIssueClosedAt = moreRecentDate
        repo.lastPullRequestClosedAt = oldestDate
        try repo.save(on: app.db).wait()

        let fetchedRepo = try XCTUnwrap(Repository.find(repo.id, on: app.db).wait())
        XCTAssertEqual(fetchedRepo.lastActivityAt, moreRecentDate)
    }

    func test_generated_lastActivityAt_lastPullRequestClosedAt() throws {
        let pkg = Package(url: "p1")
        try pkg.save(on: app.db).wait()

        let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
        let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

        let repo = try Repository(package: pkg)
        repo.lastCommitDate = oldestDate
        repo.lastIssueClosedAt = oldestDate
        repo.lastPullRequestClosedAt = moreRecentDate
        try repo.save(on: app.db).wait()

        let fetchedRepo = try XCTUnwrap(Repository.find(repo.id, on: app.db).wait())
        XCTAssertEqual(fetchedRepo.lastActivityAt, moreRecentDate)
    }

    func test_generated_lastActivityAt_nullValues() throws {
        let pkg = Package(url: "p1")
        try pkg.save(on: app.db).wait()

        let date = Date(timeIntervalSinceReferenceDate: 0)

        let repo = try Repository(package: pkg)
        repo.lastCommitDate = date
        repo.lastIssueClosedAt = nil
        repo.lastPullRequestClosedAt = nil
        try repo.save(on: app.db).wait()

        let fetchedRepo = try XCTUnwrap(Repository.find(repo.id, on: app.db).wait())
        XCTAssertEqual(fetchedRepo.lastActivityAt, date)
    }

    func test_package_relationship() throws {
        let pkg = Package(url: "p1")
        try pkg.save(on: app.db).wait()
        let repo = try Repository(package: pkg)
        try repo.save(on: app.db).wait()
        // test some ways to resolve the relationship
        XCTAssertEqual(repo.$package.id, pkg.id)
        XCTAssertEqual(try repo.$package.get(on: app.db).wait().url, "p1")
        
        // ensure one-to-one is in place
        do {
            let repo = try Repository(package: pkg)
            XCTAssertThrowsError(try repo.save(on: app.db).wait())
            XCTAssertEqual(try Repository.query(on: app.db).all().wait().count, 1)
        }
    }
    
    func test_forkedFrom_relationship() throws {
        let p1 = Package(url: "p1")
        try p1.save(on: app.db).wait()
        let p2 = Package(url: "p2")
        try p2.save(on: app.db).wait()
        
        // test forked from link
        let parent = try Repository(package: p1)
        try parent.save(on: app.db).wait()
        let child = try Repository(package: p2, forkedFrom: parent)
        try child.save(on: app.db).wait()
    }
    
    func test_delete_cascade() throws {
        // delete package must delete repository
        let pkg = Package(id: UUID(), url: "1")
        let repo = try Repository(id: UUID(), package: pkg)
        try pkg.save(on: app.db).wait()
        try repo.save(on: app.db).wait()
        
        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 1)
        XCTAssertEqual(try Repository.query(on: app.db).count().wait(), 1)
        
        // MUT
        try pkg.delete(on: app.db).wait()
        
        // version and product should be deleted
        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 0)
        XCTAssertEqual(try Repository.query(on: app.db).count().wait(), 0)
    }
    
    func test_uniqueOwnerRepository() throws {
        // Ensure owner/repository is unique, testing various combinations with
        // matching/non-matching case
        let p1 = try savePackage(on: app.db, "1")
        try Repository(id: UUID(), package: p1, name: "bar", owner: "foo").save(on: app.db).wait()
        let p2 = try savePackage(on: app.db, "2")
        
        XCTAssertThrowsError(
            // MUT - identical
            try Repository(id: UUID(), package: p2, name: "bar", owner: "foo").save(on: app.db).wait()
        ) {
            XCTAssert($0.localizedDescription.contains(
                        #"duplicate key value violates unique constraint "idx_repositories_owner_name""#))
            XCTAssertEqual(try! Repository.query(on: app.db).all().wait().count, 1)
        }
        
        XCTAssertThrowsError(
            // MUT - diffrent case repository
            try Repository(id: UUID(), package: p2, name: "Bar", owner: "foo").save(on: app.db).wait()
        ) {
            XCTAssert($0.localizedDescription.contains(
                        #"duplicate key value violates unique constraint "idx_repositories_owner_name""#))
            XCTAssertEqual(try! Repository.query(on: app.db).all().wait().count, 1)
        }
        
        XCTAssertThrowsError(
            // MUT - diffrent case owner
            try Repository(id: UUID(), package: p2, name: "bar", owner: "Foo").save(on: app.db).wait()
        ) {
            XCTAssert($0.localizedDescription.contains(
                        #"duplicate key value violates unique constraint "idx_repositories_owner_name""#))
            XCTAssertEqual(try! Repository.query(on: app.db).all().wait().count, 1)
        }
    }
    
    func test_name_index() throws {
        let db = try XCTUnwrap(app.db as? SQLDatabase)
        // Quick way to check index exists - this will throw
        //   "server: index "idx_repositories_name" does not exist (DropErrorMsgNonExistent)"
        // if it doesn't
        XCTAssertNoThrow(try db.raw("DROP INDEX idx_repositories_name").run().wait())
        // Recreate index or else the revert in the next tests setUp is going to fail
        try db.raw(
            "CREATE INDEX idx_repositories_name ON repositories USING gin (name gin_trgm_ops)"
        ).run().wait()
    }
    
}
