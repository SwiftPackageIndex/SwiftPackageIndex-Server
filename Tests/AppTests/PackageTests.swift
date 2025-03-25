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

import Dependencies
import Fluent
import SQLKit
import Testing
import Vapor


extension AllTests.PackageTests {

    @Test func Equatable() throws {
        #expect(Package(id: .id0, url: "1".url) == Package(id: .id0, url: "2".url))
        #expect(Package() != Package())
        #expect(Package(id: .id0, url: "1".url) != Package())
    }

    @Test func Hashable() throws {
        let packages: Set = [
            Package(id: .id0, url: "1".url),
            Package(id: .id0, url: "2".url),
            Package(url: "3".url),
            Package(url: "4".url)
        ]
        #expect(packages.map { "\($0.id)" }.sorted() == [UUID.id0.uuidString, "nil", "nil"])
        #expect(packages.map { "\($0.url)" }.sorted() == ["1", "3", "4"])
    }

    @Test func cacheDirectoryName() throws {
        #expect(
            Package(url: "https://github.com/finestructure/Arena").cacheDirectoryName == "github.com-finestructure-arena")
        #expect(
            Package(url: "https://github.com/finestructure/Arena.git").cacheDirectoryName == "github.com-finestructure-arena")
        #expect(
            Package(url: "http://github.com/finestructure/Arena.git").cacheDirectoryName == "github.com-finestructure-arena")
        #expect(
            Package(url: "http://github.com/FINESTRUCTURE/ARENA.GIT").cacheDirectoryName == "github.com-finestructure-arena")
        #expect(Package(url: "foo").cacheDirectoryName == nil)
        #expect(Package(url: "http://foo").cacheDirectoryName == nil)
        #expect(Package(url: "file://foo").cacheDirectoryName == nil)
        #expect(Package(url: "http:///foo/bar").cacheDirectoryName == nil)
    }

    @Test func save_status() async throws {
        try await withApp { app in
            do {  // default status
                let pkg = Package()  // avoid using init with default argument in order to test db default
                pkg.url = "1"
                try await pkg.save(on: app.db)
                let readBack = try #require(try await Package.query(on: app.db).first())
                #expect(readBack.status == .new)
            }
            do {  // with status
                try await Package(url: "2", status: .ok).save(on: app.db)
                let pkg = try #require(try await Package.query(on: app.db).filter(by: "2").first())
                #expect(pkg.status == .ok)
            }
        }
    }

    @Test func save_scoreDetails() async throws {
        try await withDependencies {
            $0.date.now = .now
        } operation: {
            try await withApp { app in
                let pkg = Package(url: "1")
                let scoreDetails = Score.Details.mock
                pkg.scoreDetails = scoreDetails
                try await pkg.save(on: app.db)
                let readBack = try #require(try await Package.query(on: app.db).first())
                #expect(readBack.scoreDetails == scoreDetails)
            }
        }
    }

    @Test func encode() throws {
        let p = Package(id: UUID(), url: URL(string: "https://github.com/finestructure/Arena")!)
        p.status = .ok
        let data = try JSONEncoder().encode(p)
        #expect(!data.isEmpty)
    }

    @Test func decode_date() throws {
        let json = """
        {
            "id": "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE",
            "url": "https://github.com/finestructure/Arena",
            "score": 17,
            "status": "ok",
            "createdAt": 0,
            "updatedAt": 1,
            "platformCompatibility": ["macos","ios"]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let p = try decoder.decode(Package.self, from: Data(json.utf8))
        #expect(p.id?.uuidString == "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")
        #expect(p.url == "https://github.com/finestructure/Arena")
        #expect(p.status == .ok)
        #expect(p.createdAt == Date(timeIntervalSince1970: 0))
        #expect(p.updatedAt == Date(timeIntervalSince1970: 1))
        #expect(p.platformCompatibility == [.iOS, .macOS])
    }

    @Test func unique_url() async throws {
        try await withApp { app in
            try await Package(url: "p1").save(on: app.db)
            do {
                try await Package(url: "p1").save(on: app.db)
                Issue.record("Expected error")
            } catch { }
        }
    }

    @Test func filter_by_url() async throws {
        try await withApp { app in
            for url in ["https://foo.com/1", "https://foo.com/2"] {
                try await Package(url: url.url).save(on: app.db)
            }
            let res = try await Package.query(on: app.db).filter(by: "https://foo.com/1").all()
            #expect(res.map(\.url) == ["https://foo.com/1"])
        }
    }

    @Test func filter_by_urls() async throws {
        try await withApp { app in
            for url in ["https://foo.com/1.git", "https://foo.com/2.git", "https://foo.com/a.git", "https://foo.com/A.git"] {
                try await Package(url: url.url).save(on: app.db)
            }
            do { // single match
                let res = try await Package.query(on: app.db).filter(by: ["https://foo.com/2.git"]).all()
                #expect(res.map(\.url) == ["https://foo.com/2.git"])
            }
            do { // case insensitive match
                let res = try await Package.query(on: app.db).filter(by: ["https://foo.com/2.git", "https://foo.com/a.git"]).all()
                #expect(
                    res.map(\.url) == ["https://foo.com/2.git", "https://foo.com/a.git", "https://foo.com/A.git"]
                )
            }
            do { // input URLs are normalised
                let res = try await Package.query(on: app.db).filter(by: ["http://foo.com/2"]).all()
                #expect(res.map(\.url) == ["https://foo.com/2.git"])
            }
        }
    }

    @Test func repository() async throws {
        try await withApp { app in
            let pkg = try await savePackage(on: app.db, "1")
            do {
                let pkg = try #require(try await Package.query(on: app.db).with(\.$repositories).first())
                #expect(pkg.repositories.first == nil)
            }
            do {
                let repo = try Repository(package: pkg)
                try await repo.save(on: app.db)
                let pkg = try #require(try await Package.query(on: app.db).with(\.$repositories).first())
                #expect(pkg.repositories.first == repo)
            }
        }
    }

    @Test func versions() async throws {
        try await withApp { app in
            let pkg = try await savePackage(on: app.db, "1")
            let versions = [
                try Version(package: pkg, reference: .branch("branch")),
                try Version(package: pkg, reference: .branch("default")),
                try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            ]
            try await versions.create(on: app.db)
            do {
                let pkg = try #require(try await Package.query(on: app.db).with(\.$versions).first())
                #expect(pkg.versions.count == 3)
            }
        }
    }

    @Test func findBranchVersion() async throws {
        try await withApp { app in
            // setup
            let pkg = try await savePackage(on: app.db, "1")
            try await Repository(package: pkg, defaultBranch: "default").create(on: app.db)
            let versions = [
                try Version(package: pkg, reference: .branch("branch")),
                try Version(package: pkg, commitDate: Date.now.adding(days: -1),
                            reference: .branch("default")),
                try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
                try Version(package: pkg, commitDate: Date.now.adding(days: -3),
                            reference: .tag(.init(2, 1, 0))),
                try Version(package: pkg, commitDate: Date.now.adding(days: -2),
                            reference: .tag(.init(3, 0, 0, "beta"))),
            ]
            try await versions.create(on: app.db)

            // MUT
            let version = Package.findBranchVersion(versions: versions,
                                                    branch: "default")

            // validation
            #expect(version?.reference == .branch("default"))
        }
    }

    @Test func findRelease() async throws {
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            let versions: [Version] = [
                try .init(package: p, reference: .tag(2, 0, 0)),
                try .init(package: p, reference: .tag(1, 2, 3)),
                try .init(package: p, reference: .tag(1, 5, 0)),
                try .init(package: p, reference: .tag(2, 0, 0, "b1")),
            ]

            // MUT & validation
            #expect(Package.findRelease(versions)?.reference == .tag(2, 0, 0))
        }
    }

    @Test func findPreRelease() async throws {
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

            // MUT & validation
            #expect(
                Package.findPreRelease([
                    try .init(package: p, commitDate: t(2), reference: .tag(3, 0, 0, "b1")),
                    try .init(package: p, commitDate: t(0), reference: .tag(1, 2, 3)),
                    try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0)),
                ],
                                       after: .tag(2, 0, 0))?.reference == .tag(3, 0, 0, "b1")
            )
            // ensure a beta doesn't come after its release
            #expect(
                Package.findPreRelease([
                    try .init(package: p, commitDate: t(3), reference: .tag(3, 0, 0)),
                    try .init(package: p, commitDate: t(2), reference: .tag(3, 0, 0, "b1")),
                    try .init(package: p, commitDate: t(0), reference: .tag(1, 2, 3)),
                    try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0)),
                ],
                                       after: .tag(3, 0, 0))?.reference == nil
            )
        }
    }

    @Test func findPreRelease_double_digit_build() async throws {
        // Test pre-release sorting of betas with double digit build numbers,
        // e.g. 2.0.0-b11 should come after 2.0.0-b9
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/706
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

            // MUT & validation
            #expect(
                Package.findPreRelease([
                    try .init(package: p, commitDate: t(0), reference: .tag(2, 0, 0, "b9")),
                    try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0, "b10")),
                    try .init(package: p, commitDate: t(2), reference: .tag(2, 0, 0, "b11")),
                ],
                                       after: nil)?.reference == .tag(2, 0, 0, "b11")
            )
        }
    }

    @Test func findSignificantReleases_old_beta() async throws {
        // Test to ensure outdated betas aren't picked up as latest versions
        try await withApp { app in
            // setup
            let pkg = Package(id: UUID(), url: "1")
            try await pkg.save(on: app.db)
            try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
            let versions = [
                try Version(package: pkg, packageName: "foo", reference: .branch("main")),
                try Version(package: pkg, packageName: "foo", reference: .tag(2, 0, 0)),
                try Version(package: pkg, packageName: "foo", reference: .tag(2, 0, 0, "rc1"))
            ]
            try await versions.save(on: app.db)

            // MUT
            let (release, preRelease, defaultBranch) = Package.findSignificantReleases(versions: versions, branch: "main")

            // validate
            #expect(release?.reference == .tag(2, 0, 0))
            #expect(preRelease == nil)
            #expect(defaultBranch?.reference == .branch("main"))
        }
    }

    @Test func versionUrl() throws {
        #expect(Package(url: "https://github.com/foo/bar").versionUrl(for: .tag(1, 2, 3)) == "https://github.com/foo/bar/releases/tag/1.2.3")
        #expect(Package(url: "https://github.com/foo/bar").versionUrl(for: .branch("main")) == "https://github.com/foo/bar/tree/main")
        #expect(Package(url: "https://gitlab.com/foo/bar").versionUrl(for: .tag(1, 2, 3)) == "https://gitlab.com/foo/bar/-/tags/1.2.3")
        #expect(Package(url: "https://gitlab.com/foo/bar").versionUrl(for: .branch("main")) == "https://gitlab.com/foo/bar/-/tree/main")
        // ensure .git is stripped off
        #expect(Package(url: "https://github.com/foo/bar.git").versionUrl(for: .tag(1, 2, 3)) == "https://github.com/foo/bar/releases/tag/1.2.3")
    }

    @Test func isNew() async throws {
        let url = "1".asGithubUrl
        try await withDependencies {
            $0.date.now = .now
            $0.fileManager.fileExists = { @Sendable _ in true }
            $0.git.commitCount = { @Sendable _ in 12 }
            $0.git.firstCommitDate = { @Sendable _ in .t0 }
            $0.git.getTags = { @Sendable _ in [] }
            $0.git.hasBranch = { @Sendable _, _ in true }
            $0.git.lastCommitDate = { @Sendable _ in .t1 }
            $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha", date: .t0) }
            $0.git.shortlog = { @Sendable _ in
                """
                10\tPerson 1
                 2\tPerson 2
                """
            }
            $0.github.fetchLicense = { @Sendable _, _ in nil }
            $0.github.fetchMetadata = { @Sendable owner, repository in .mock(owner: owner, repository: repository) }
            $0.github.fetchReadme = { @Sendable _, _ in nil }
            $0.packageListRepository.fetchPackageList = { @Sendable _ in [url.url] }
            $0.packageListRepository.fetchPackageDenyList = { @Sendable _ in [] }
            $0.packageListRepository.fetchCustomCollections = { @Sendable _ in [] }
            $0.shell.run = { @Sendable cmd, path in
                if cmd.description.hasSuffix("swift package dump-package") {
                    return #"{ "name": "Mock", "products": [] }"#
                }
                return ""
            }
        } operation: {
            try await withApp { app in
                // setup
                let db = app.db
                // run reconcile to ingest package
                try await reconcile(client: app.client, database: app.db)
                #expect(try await Package.query(on: db).count() == 1)

                // MUT & validate
                do {
                    let pkg = try #require(try await Package.query(on: app.db).first())
                    #expect(pkg.isNew)
                }

                // run ingestion to progress package through pipeline
                try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))

                // MUT & validate
                do {
                    let pkg = try #require(try await Package.query(on: app.db).first())
                    #expect(pkg.isNew)
                }

                // run analysis to progress package through pipeline
                try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(10))

                // MUT & validate
                do {
                    let pkg = try #require(try await Package.query(on: app.db).first())
                    #expect(!pkg.isNew)
                }

                // run stages again to simulate the cycle...

                try await reconcile(client: app.client, database: app.db)
                do {
                    let pkg = try #require(try await Package.query(on: app.db).first())
                    #expect(!pkg.isNew)
                }

                try await withDependencies {
                    $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime)
                } operation: {
                    try await Ingestion.ingest(client: app.client, database: app.db, mode: .limit(10))

                    do {
                        let pkg = try #require(try await Package.query(on: app.db).first())
                        #expect(!pkg.isNew)
                    }

                    try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(10))

                    do {
                        let pkg = try #require(try await Package.query(on: app.db).first())
                        #expect(!pkg.isNew)
                    }
                }
            }
        }
    }

    @Test func isNew_processingStage_nil() {
        // ensure a package with processingStage == nil is new
        // MUT & validate
        let pkg = Package(url: "1", processingStage: nil)
        #expect(pkg.isNew)
    }

    @Test func save_platformCompatibility_save() async throws {
        try await withApp { app in
            try await Package(url: "1".url, platformCompatibility: [.iOS, .macOS, .iOS])
                .save(on: app.db)
            let readBack = try #require(try await Package.query(on: app.db).first())
            #expect(readBack.platformCompatibility == [.iOS, .macOS])
        }
    }

    @Test func save_platformCompatibility_read_nonunique() async throws {
        // test reading back of a non-unique array (this shouldn't be
        // occuring but we can't enforce a set at the DDL level so it's
        // technically possible and we want to ensure it doesn't cause
        // errors)
        try await withApp { app in
            try await Package(url: "1".url).save(on: app.db)
            try await (app.db as! SQLDatabase).raw(
                "update packages set platform_compatibility = '{ios,ios}'"
            ).run()
            let readBack = try #require(try await Package.query(on: app.db).first())
            #expect(readBack.platformCompatibility == [.iOS])
        }
    }

    @Test func updatePlatformCompatibility() async throws {
        try await withApp { app in
            // setup
            let p = try await savePackage(on: app.db, "1")
            let v = try Version(package: p, latest: .defaultBranch)
            try await v.save(on: app.db)
            for platform in Build.Platform.allCases {
                // Create a build record for each platform to ensure we can read back
                // any mapped build correctly.
                // For instance, if macos-spm wasn't mapped to macos in the update statement,
                // reading back that package would fail when de-serialising `macos-spm`
                // into `Package.PlatformCompatibility`, because it has no such enum
                // case.
                // We need to test this explicitly, because the raw SQL update statement
                // in combination with a plain TEXT[] backing field for
                // platform_compatibility prevents us from relying on type safety.
                // This test ensures that a newly added case in Build.Platform
                // must also be handled in the updatePlatformCompatibility SQL
                // statement.
                // If it isn't, this test will fail with:
                // invalid field: platform_compatibility type: Set<PlatformCompatibility> error: Unexpected data type: TEXT. Expected jsonb/json
                // (which is a bit obscure but means that the content of
                // platform_compatibility cannot be de-serialised into
                // PlatformCompatibility)
                try await Build(version: v, platform: platform, status: .ok, swiftVersion: .v1)
                    .save(on: app.db)
            }
            try await savePackage(on: app.db, "2")

            // MUT
            try await Package.updatePlatformCompatibility(for: p.requireID(), on: app.db)

            // validate
            let p1 = try #require(
                try await Package.query(on: app.db).filter(by: "1".url).first()
            )
            #expect(p1.platformCompatibility == [.iOS, .macOS, .linux, .tvOS, .visionOS, .watchOS])
            let p2 = try #require(
                try await Package.query(on: app.db).filter(by: "2".url).first()
            )
            #expect(p2.platformCompatibility == [])
        }
    }

}
