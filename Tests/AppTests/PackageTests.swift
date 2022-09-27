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

import Fluent
import SQLKit
import Vapor
import XCTVapor


final class PackageTests: AppTestCase {

    func test_Equatable() throws {
        XCTAssertEqual(Package(id: .id0, url: "1".url),
                       Package(id: .id0, url: "2".url))
        XCTAssertFalse(Package() == Package())
        XCTAssertFalse(Package(id: .id0, url: "1".url) == Package())
    }

    func test_Hashable() throws {
        let packages: Set = [
            Package(id: .id0, url: "1".url),
            Package(id: .id0, url: "2".url),
            Package(url: "3".url),
            Package(url: "4".url)
        ]
        XCTAssertEqual(packages.map { "\($0.id)" }.sorted(),
                       [UUID.id0.uuidString, "nil", "nil"])
        XCTAssertEqual(packages.map { "\($0.url)" }.sorted(),
                       ["1", "3", "4"])
    }

    func test_cacheDirectoryName() throws {
        XCTAssertEqual(
            Package(url: "https://github.com/finestructure/Arena").cacheDirectoryName,
            "github.com-finestructure-arena")
        XCTAssertEqual(
            Package(url: "https://github.com/finestructure/Arena.git").cacheDirectoryName,
            "github.com-finestructure-arena")
        XCTAssertEqual(
            Package(url: "http://github.com/finestructure/Arena.git").cacheDirectoryName,
            "github.com-finestructure-arena")
        XCTAssertEqual(
            Package(url: "http://github.com/FINESTRUCTURE/ARENA.GIT").cacheDirectoryName,
            "github.com-finestructure-arena")
        XCTAssertEqual(Package(url: "foo").cacheDirectoryName, nil)
        XCTAssertEqual(Package(url: "http://foo").cacheDirectoryName, nil)
        XCTAssertEqual(Package(url: "file://foo").cacheDirectoryName, nil)
        XCTAssertEqual(Package(url: "http:///foo/bar").cacheDirectoryName, nil)
    }
    
    func test_save_status() throws {
        do {  // default status
            let pkg = Package()  // avoid using init with default argument in order to test db default
            pkg.url = "1"
            try pkg.save(on: app.db).wait()
            let readBack = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertEqual(readBack.status, .new)
        }
        do {  // with status
            try Package(url: "2", status: .ok).save(on: app.db).wait()
            let pkg = try XCTUnwrap(try Package.query(on: app.db).filter(by: "2").first().wait())
            XCTAssertEqual(pkg.status, .ok)
        }
    }
    
    func test_encode() throws {
        let p = Package(id: UUID(), url: URL(string: "https://github.com/finestructure/Arena")!)
        p.status = .ok
        let data = try JSONEncoder().encode(p)
        XCTAssertTrue(!data.isEmpty)
    }
    
    func test_decode_date() throws {
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
        XCTAssertEqual(p.id?.uuidString, "CAFECAFE-CAFE-CAFE-CAFE-CAFECAFECAFE")
        XCTAssertEqual(p.url, "https://github.com/finestructure/Arena")
        XCTAssertEqual(p.status, .ok)
        XCTAssertEqual(p.createdAt, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(p.updatedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(p.platformCompatibility, [.ios, .macos])
    }
    
    func test_unique_url() throws {
        try Package(url: "p1").save(on: app.db).wait()
        XCTAssertThrowsError(try Package(url: "p1").save(on: app.db).wait())
    }
    
    func test_filter_by_url() throws {
        try ["https://foo.com/1", "https://foo.com/2"].forEach {
            try Package(url: $0).save(on: app.db).wait()
        }
        let res = try Package.query(on: app.db).filter(by: "https://foo.com/1").all().wait()
        XCTAssertEqual(res.map(\.url), ["https://foo.com/1"])
    }
    
    func test_repository() throws {
        let pkg = try savePackage(on: app.db, "1")
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).with(\.$repositories).first().wait())
            XCTAssertEqual(pkg.repositories.first, nil)
        }
        do {
            let repo = try Repository(package: pkg)
            try repo.save(on: app.db).wait()
            let pkg = try XCTUnwrap(Package.query(on: app.db).with(\.$repositories).first().wait())
            XCTAssertEqual(pkg.repositories.first, repo)
        }
    }
    
    func test_versions() throws {
        let pkg = try savePackage(on: app.db, "1")
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, reference: .branch("default")),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
        ]
        try versions.create(on: app.db).wait()
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).with(\.$versions).first().wait())
            XCTAssertEqual(pkg.versions.count, 3)
        }
    }

    func test_findBranchVersion() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1")
        try Repository(package: pkg, defaultBranch: "default").create(on: app.db).wait()
        let versions = [
            try Version(package: pkg, reference: .branch("branch")),
            try Version(package: pkg, commitDate: daysAgo(1), reference: .branch("default")),
            try Version(package: pkg, reference: .tag(.init(1, 2, 3))),
            try Version(package: pkg, commitDate: daysAgo(3), reference: .tag(.init(2, 1, 0))),
            try Version(package: pkg, commitDate: daysAgo(2), reference: .tag(.init(3, 0, 0, "beta"))),
        ]
        try versions.create(on: app.db).wait()

        // MUT
        let version = Package.findBranchVersion(versions: versions,
                                                branch: "default")

        // validation
        XCTAssertEqual(version?.reference, .branch("default"))
    }

    func test_findRelease() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        let versions: [Version] = [
            try .init(package: p, reference: .tag(2, 0, 0)),
            try .init(package: p, reference: .tag(1, 2, 3)),
            try .init(package: p, reference: .tag(1, 5, 0)),
            try .init(package: p, reference: .tag(2, 0, 0, "b1")),
        ]

        // MUT & validation
        XCTAssertEqual(Package.findRelease(versions)?.reference, .tag(2, 0, 0))
    }

    func test_findPreRelease() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

        // MUT & validation
        XCTAssertEqual(
            Package.findPreRelease([
                try .init(package: p, commitDate: t(2), reference: .tag(3, 0, 0, "b1")),
                try .init(package: p, commitDate: t(0), reference: .tag(1, 2, 3)),
                try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0)),
            ],
            after: .tag(2, 0, 0))?.reference,
            .tag(3, 0, 0, "b1")
        )
        // ensure a beta doesn't come after its release
        XCTAssertEqual(
            Package.findPreRelease([
                try .init(package: p, commitDate: t(3), reference: .tag(3, 0, 0)),
                try .init(package: p, commitDate: t(2), reference: .tag(3, 0, 0, "b1")),
                try .init(package: p, commitDate: t(0), reference: .tag(1, 2, 3)),
                try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0)),
            ],
            after: .tag(3, 0, 0))?.reference,
            nil
        )
    }

    func test_findPreRelease_double_digit_build() throws {
        // Test pre-release sorting of betas with double digit build numbers,
        // e.g. 2.0.0-b11 should come after 2.0.0-b9
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/706
        // setup
        let p = try savePackage(on: app.db, "1")
        func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

        // MUT & validation
        XCTAssertEqual(
            Package.findPreRelease([
                try .init(package: p, commitDate: t(0), reference: .tag(2, 0, 0, "b9")),
                try .init(package: p, commitDate: t(1), reference: .tag(2, 0, 0, "b10")),
                try .init(package: p, commitDate: t(2), reference: .tag(2, 0, 0, "b11")),
            ],
            after: nil)?.reference,
            .tag(2, 0, 0, "b11")
        )
    }

    func test_findSignificantReleases_old_beta() throws {
        // Test to ensure outdated betas aren't picked up as latest versions
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        let versions = [
            try Version(package: pkg, packageName: "foo", reference: .branch("main")),
            try Version(package: pkg, packageName: "foo", reference: .tag(2, 0, 0)),
            try Version(package: pkg, packageName: "foo", reference: .tag(2, 0, 0, "rc1"))
        ]
        try versions.save(on: app.db).wait()

        // MUT
        let (release, preRelease, defaultBranch) = Package.findSignificantReleases(versions: versions, branch: "main")

        // validate
        XCTAssertEqual(release?.reference, .tag(2, 0, 0))
        XCTAssertEqual(preRelease, nil)
        XCTAssertEqual(defaultBranch?.reference, .branch("main"))
    }

    func test_versionUrl() throws {
        XCTAssertEqual(Package(url: "https://github.com/foo/bar").versionUrl(for: .tag(1, 2, 3)),
                       "https://github.com/foo/bar/releases/tag/1.2.3")
        XCTAssertEqual(Package(url: "https://github.com/foo/bar").versionUrl(for: .branch("main")),
                       "https://github.com/foo/bar/tree/main")
        XCTAssertEqual(Package(url: "https://gitlab.com/foo/bar").versionUrl(for: .tag(1, 2, 3)),
                       "https://gitlab.com/foo/bar/-/tags/1.2.3")
        XCTAssertEqual(Package(url: "https://gitlab.com/foo/bar").versionUrl(for: .branch("main")),
                       "https://gitlab.com/foo/bar/-/tree/main")
        // ensure .git is stripped off
        XCTAssertEqual(Package(url: "https://github.com/foo/bar.git").versionUrl(for: .tag(1, 2, 3)),
                       "https://github.com/foo/bar/releases/tag/1.2.3")
    }

    func test_isNew() async throws {
        // setup
        let url = "1".asGithubUrl
        Current.fetchMetadata = { _, pkg in .mock(for: pkg) }
        Current.fetchPackageList = { _ in [url.url] }
        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in Date(timeIntervalSince1970: 0) }
        Current.git.getTags = { _ in [] }
        Current.git.lastCommitDate = { _ in Date(timeIntervalSince1970: 1) }
        Current.git.revisionInfo = { _, _ in
            .init(commit: "sha",
                  date: Date(timeIntervalSince1970: 0))
        }
        Current.git.shortlog = { _ in
            """
            10 Person 1 <person1@example.com>
             2 Person 2 <person2@example.com>
            """
        }
        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                return #"{ "name": "Mock", "products": [] }"#
            }
            return ""
        }
        // run reconcile to ingest package
        try await reconcile(client: app.client, database: app.db)
        XCTAssertEqual(try Package.query(on: app.db).count().wait(), 1)

        // MUT & validate
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertTrue(pkg.isNew)
        }

        // run ingestion to progress package through pipeline
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))

        // MUT & validate
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertTrue(pkg.isNew)
        }

        // run analysis to progress package through pipeline
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // MUT & validate
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertFalse(pkg.isNew)
        }

        // run stages again to simulate the cycle...

        try await reconcile(client: app.client, database: app.db)
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertFalse(pkg.isNew)
        }

        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime) }
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertFalse(pkg.isNew)
        }

        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))
        do {
            let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
            XCTAssertFalse(pkg.isNew)
        }
    }

    func test_isNew_processingStage_nil() {
        // ensure a package with processingStage == nil is new
        // MUT & validate
        let pkg = Package(url: "1", processingStage: nil)
        XCTAssertTrue(pkg.isNew)
    }

    func test_save_platformCompatibility_save() throws {
        try Package(url: "1".url, platformCompatibility: [.ios, .macos, .ios])
            .save(on: app.db).wait()
        let readBack = try XCTUnwrap(Package.query(on: app.db).first().wait())
        XCTAssertEqual(readBack.platformCompatibility, [.ios, .macos])
    }

    func test_save_platformCompatibility_read_nonunique() throws {
        // test reading back of a non-unique array (this shouldn't be
        // occuring but we can't enforce a set at the DDL level so it's
        // technically possible and we want to ensure it doesn't cause
        // errors)
        try Package(url: "1".url).save(on: app.db).wait()
        try (app.db as! SQLDatabase).raw(
            "update packages set platform_compatibility = '{ios,ios}'"
        ).run().wait()
        let readBack = try XCTUnwrap(Package.query(on: app.db).first().wait())
        XCTAssertEqual(readBack.platformCompatibility, [.ios])
    }

    func test_updatePlatformCompatibility() async throws {
        // setup
        let p = try savePackage(on: app.db, "1")
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
            try await Build(version: v, platform: platform, status: .ok, swiftVersion: .v5_5)
                .save(on: app.db)
        }
        try savePackage(on: app.db, "2")

        // MUT
        try await Package.updatePlatformCompatibility(for: p.requireID(), on: app.db)

        // validate
        let p1 = try XCTUnwrap(
            Package.query(on: app.db).filter(by: "1".url).first().wait()
        )
        XCTAssertEqual(p1.platformCompatibility, [.ios, .macos, .linux, .tvos, .watchos])
        let p2 = try XCTUnwrap(
            Package.query(on: app.db).filter(by: "2".url).first().wait()
        )
        XCTAssertEqual(p2.platformCompatibility, [])
    }

}


func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .init(day: -days), to: Current.date())!
}
