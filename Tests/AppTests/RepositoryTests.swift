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

import Foundation

@testable import App

import SQLKit
import Testing


extension AllTests.RepositoryTests {

    @Test func save() async throws {
        try await withApp { app in
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
                let r = try #require(try await Repository.find(repo.id, on: app.db))
                #expect(r.$package.id == pkg.id)
                #expect(r.authors == PackageAuthors(authors: [ .init(name: "Foo"), .init(name: "Bar")],
                                                    numberOfContributors: 0))
                #expect(r.commitCount == 123)
                #expect(r.defaultBranch == "branch")
                #expect(r.firstCommitDate == Date(timeIntervalSince1970: 0))
                #expect(r.forks == 17)
                #expect(r.forkedFrom == nil)
                #expect(r.isArchived == true)
                #expect(r.keywords == ["foo", "bar"])
                #expect(r.lastCommitDate == Date(timeIntervalSince1970: 1))
                #expect(r.lastIssueClosedAt == Date(timeIntervalSince1970: 2))
                #expect(r.lastPullRequestClosedAt == Date(timeIntervalSince1970: 3))
                #expect(r.license == .mit)
                #expect(r.licenseUrl == "https://github.com/foo/bar/blob/main/LICENSE")
                #expect(r.openIssues == 3)
                #expect(r.openPullRequests == 4)
                #expect(r.s3Readme == .cached(s3ObjectUrl: "objectUrl", githubEtag: "etag"))
                #expect(r.readmeHtmlUrl == "https://github.com/foo/bar/blob/main/README.md")
                #expect(r.releases == [
                    .init(description: "a release",
                          isDraft: false,
                          publishedAt: Date(timeIntervalSince1970: 1),
                          tagName: "1.2.3",
                          url: "https://example.com/release/1.2.3")
                ])
                #expect(r.stars == 42)
                #expect(r.summary == "desc")
            }
        }
    }

    @Test func generated_lastActivityAt_lastCommitDate() async throws {
        try await withApp { app in
            let pkg = Package(url: "p1")
            try await pkg.save(on: app.db)

            let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
            let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

            let repo = try Repository(package: pkg)
            repo.lastCommitDate = moreRecentDate
            repo.lastIssueClosedAt = oldestDate
            repo.lastPullRequestClosedAt = oldestDate
            try await repo.save(on: app.db)

            let fetchedRepo = try #require(try await Repository.find(repo.id, on: app.db))
            #expect(fetchedRepo.lastActivityAt == moreRecentDate)
        }
    }

    @Test func generated_lastActivityAt_lastIssueClosedAt() async throws {
        try await withApp { app in
            let pkg = Package(url: "p1")
            try await pkg.save(on: app.db)

            let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
            let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

            let repo = try Repository(package: pkg)
            repo.lastCommitDate = oldestDate
            repo.lastIssueClosedAt = moreRecentDate
            repo.lastPullRequestClosedAt = oldestDate
            try await repo.save(on: app.db)

            let fetchedRepo = try #require(try await Repository.find(repo.id, on: app.db))
            #expect(fetchedRepo.lastActivityAt == moreRecentDate)
        }
    }

    @Test func generated_lastActivityAt_lastPullRequestClosedAt() async throws {
        try await withApp { app in
            let pkg = Package(url: "p1")
            try await pkg.save(on: app.db)

            let oldestDate = Date(timeIntervalSinceReferenceDate: 0)
            let moreRecentDate = Date(timeIntervalSinceReferenceDate: 100)

            let repo = try Repository(package: pkg)
            repo.lastCommitDate = oldestDate
            repo.lastIssueClosedAt = oldestDate
            repo.lastPullRequestClosedAt = moreRecentDate
            try await repo.save(on: app.db)

            let fetchedRepo = try #require(try await Repository.find(repo.id, on: app.db))
            #expect(fetchedRepo.lastActivityAt == moreRecentDate)
        }
    }

    @Test func generated_lastActivityAt_nullValues() async throws {
        try await withApp { app in
            let pkg = Package(url: "p1")
            try await pkg.save(on: app.db)

            let date = Date(timeIntervalSinceReferenceDate: 0)

            let repo = try Repository(package: pkg)
            repo.lastCommitDate = date
            repo.lastIssueClosedAt = nil
            repo.lastPullRequestClosedAt = nil
            try await repo.save(on: app.db)

            let fetchedRepo = try #require(try await Repository.find(repo.id, on: app.db))
            #expect(fetchedRepo.lastActivityAt == date)
        }
    }

    @Test func package_relationship() async throws {
        try await withApp { app in
            let pkg = Package(url: "p1")
            try await pkg.save(on: app.db)
            let repo = try Repository(package: pkg)
            try await repo.save(on: app.db)
            // test some ways to resolve the relationship
            #expect(repo.$package.id == pkg.id)
            let db = app.db
            #expect(try await repo.$package.get(on: db).url == "p1")

            // ensure one-to-one is in place
            do {
                let repo = try Repository(package: pkg)
                do {
                    try await repo.save(on: app.db)
                    Issue.record("Expected error")
                } catch { }
                #expect(try await Repository.query(on: db).all().count == 1)
            }
        }
    }

    @Test func delete_cascade() async throws {
        // delete package must delete repository
        try await withApp { app in
            let pkg = Package(id: UUID(), url: "1")
            let repo = try Repository(id: UUID(), package: pkg)
            try await pkg.save(on: app.db)
            try await repo.save(on: app.db)

            let db = app.db
            #expect(try await Package.query(on: db).count() == 1)
            #expect(try await Repository.query(on: db).count() == 1)

            // MUT
            try await pkg.delete(on: app.db)

            // version and product should be deleted
            #expect(try await Package.query(on: db).count() == 0)
            #expect(try await Repository.query(on: db).count() == 0)
        }
    }

    @Test func uniqueOwnerRepository() async throws {
        // Ensure owner/repository is unique, testing various combinations with
        // matching/non-matching case
        try await withApp { app in
            let p1 = try await savePackage(on: app.db, "1")
            try await Repository(id: UUID(), package: p1, name: "bar", owner: "foo").save(on: app.db)
            let p2 = try await savePackage(on: app.db, "2")
            let db = app.db

            do {
                // MUT - identical
                try await Repository(id: UUID(), package: p2, name: "bar", owner: "foo").save(on: app.db)
                Issue.record("Expected error")
            } catch {
                #expect(String(reflecting: error).contains(
                    #"duplicate key value violates unique constraint "idx_repositories_owner_name""#),
                        "was: \(error.localizedDescription)"
                )
                #expect(try await Repository.query(on: db).all().count == 1)
            }

            do {
                // MUT - diffrent case repository
                try await Repository(id: UUID(), package: p2, name: "Bar", owner: "foo").save(on: app.db)
                Issue.record("Expected error")
            } catch {
                #expect(String(reflecting: error).contains(
                    #"duplicate key value violates unique constraint "idx_repositories_owner_name""#),
                        "was: \(error.localizedDescription)"
                )
                #expect(try await Repository.query(on: db).all().count == 1)
            }

            do {
                // MUT - diffrent case owner
                try await Repository(id: UUID(), package: p2, name: "bar", owner: "Foo").save(on: app.db)
                Issue.record("Expected error")
            } catch {
                #expect(String(reflecting: error).contains(
                    #"duplicate key value violates unique constraint "idx_repositories_owner_name""#),
                        "was: \(error.localizedDescription)"
                )
                #expect(try await Repository.query(on: db).all().count == 1)
            }
        }
    }

    @Test func name_index() async throws {
        try await withApp { app in
            let db = try #require(app.db as? SQLDatabase)
            // Quick way to check index exists - this will throw
            //   "server: index "idx_repositories_name" does not exist (DropErrorMsgNonExistent)"
            // if it doesn't
            try await db.raw("DROP INDEX idx_repositories_name").run()
            // Recreate index or else the revert in the next tests setUp is going to fail
            try await db.raw("CREATE INDEX idx_repositories_name ON repositories USING gin (name gin_trgm_ops)").run()
        }
    }

    @Test func S3Readme_needsUpdate() {
        #expect(S3Readme.error("").needsUpdate(upstreamEtag: "etag"))
        #expect(!S3Readme.cached(s3ObjectUrl: "", githubEtag: "old etag").needsUpdate(upstreamEtag: "old etag"))
        #expect(S3Readme.cached(s3ObjectUrl: "", githubEtag: "old etag").needsUpdate(upstreamEtag: "new etag"))
    }

}
