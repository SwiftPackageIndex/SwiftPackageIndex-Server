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
import XCTest


class ReAnalyzeVersionsTests: AppTestCase {

    func test_reAnalyzeVersions() async throws {
        // Basic end-to-end test
        // setup
        // - package dump does not include toolsVersion, targets to simulate an "old version"
        // - run analysis to create existing version
        // - validate that initial state is reflected
        // - then change input data in fields that are affecting existing versions (which `analysis` is "blind" to)
        // - run analysis again to confirm "blindness"
        // - run re-analysis and confirm changes are now reflected
        let pkg = try savePackage(on: app.db,
                                  "https://github.com/foo/1".url,
                                  processingStage: .ingestion)
        let repoId = UUID()
        try await Repository(id: repoId,
                             package: pkg,
                             defaultBranch: "main",
                             name: "1",
                             owner: "foo").save(on: app.db)

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.getTags = { _ in [.tag(1, 2, 3)] }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }
        Current.git.shortlog = { _ in
            """
            10 Person 1 <person1@example.com>
             2 Person 2 <person2@example.com>
            """
        }

        var pkgDump = #"""
            {
              "name": "SPI-Server",
              "products": [],
              "targets": []
            }
            """#
        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                return pkgDump
            }
            return ""
        }
        do {
            // run initial analysis and assert initial state for versions
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      logger: app.logger,
                                      mode: .limit(10))
            let versions = try await Version.query(on: app.db)
                .with(\.$targets)
                .all()
            XCTAssertEqual(versions.map(\.toolsVersion), [nil, nil])
            XCTAssertEqual(versions.map { $0.targets.map(\.name) } , [[], []])
            XCTAssertEqual(versions.map(\.releaseNotes) , [nil, nil])
        }
        do {
            // Update state that would normally not be affecting existing versions, effectively simulating the situation where we only started parsing it after versions had already been created
            pkgDump = #"""
            {
              "name": "SPI-Server",
              "products": [],
              "targets": [{"name": "t1", "type": "regular"}],
              "toolsVersion": {
                "_version": "5.3"
              }
            }
            """#
            // also, update release notes to ensure mergeReleaseInfo is being called
            let r = try await Repository.find(repoId, on: app.db).unwrap()
            r.releases = [
                .mock(description: "rel 1.2.3", tagName: "1.2.3")
            ]
            try r.save(on: app.db).wait()
            // Package has gained a SPI manifest
            Current.loadSPIManifest = { path in
                if path.hasSuffix("foo-1") {
                    return .init(builder: .init(configs: [.init(documentationTargets: ["DocTarget"])]))
                } else {
                    return nil
                }
            }
        }
        do {  // assert running analysis again does not update existing versions
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      logger: app.logger,
                                      mode: .limit(10))
            let versions = try Version.query(on: app.db)
                .with(\.$targets)
                .all().wait()
            XCTAssertEqual(versions.map(\.toolsVersion), [nil, nil])
            XCTAssertEqual(versions.map { $0.targets.map(\.name) } , [[], []])
            XCTAssertEqual(versions.map(\.releaseNotes) , [nil, nil])
            XCTAssertEqual(versions.map(\.docArchives), [nil, nil])
        }

        // MUT
        try await ReAnalyzeVersions.reAnalyzeVersions(client: app.client,
                                                      database: app.db,
                                                      logger: app.logger,
                                                      before: Current.date(),
                                                      refreshCheckouts: false,
                                                      limit: 10)

        // validate that re-analysis has now updated existing versions
        let versions = try Version.query(on: app.db)
            .with(\.$targets)
            .sort(\.$createdAt)
            .all().wait()
        XCTAssertEqual(versions.map(\.toolsVersion), ["5.3", "5.3"])
        XCTAssertEqual(versions.map { $0.targets.map(\.name) } , [["t1"], ["t1"]])
        XCTAssertEqual(versions.compactMap(\.releaseNotes) , ["rel 1.2.3"])
    }

    func test_Package_fetchReAnalysisCandidates() async throws {
        // Three packages with two versions:
        // 1) both versions updated before cutoff -> candidate
        // 2) one version update before cutoff, one after -> candidate
        // 3) both version updated after cutoff -> not a candidate
        let cutoff = Date(timeIntervalSince1970: 2)
        do {
            let p = Package(url: "1")
            try await p.save(on: app.db)
            try createVersion(app.db, p, updatedAt: .t0)
            try createVersion(app.db, p, updatedAt: .t1)
        }
        do {
            let p = Package(url: "2")
            try await p.save(on: app.db)
            try createVersion(app.db, p, updatedAt: .t1)
            try createVersion(app.db, p, updatedAt: .t3)
        }
        do {
            let p = Package(url: "3")
            try await p.save(on: app.db)
            try createVersion(app.db, p, updatedAt: .t3)
            try createVersion(app.db, p, updatedAt: .t4)
        }

        // MUT
        let res = try await Package
            .fetchReAnalysisCandidates(app.db, before: cutoff, limit: 10)

        // validate
        XCTAssertEqual(res.map(\.model.url), ["1", "2"])
    }

    func test_versionsUpdatedOnError() async throws {
        // Test to ensure versions are updated even if processing throws errors.
        // This is to ensure our candidate selection shrinks and we don't
        // churn over and over on failing versions.
        let cutoff = Date.t1
        Current.date = { .t2 }
        let pkg = try savePackage(on: app.db,
                                  "https://github.com/foo/1".url,
                                  processingStage: .ingestion)
        try await Repository(package: pkg,
                             defaultBranch: "main").save(on: app.db)
        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.getTags = { _ in [] }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }
        Current.git.shortlog = { _ in
            """
            10 Person 1 <person1@example.com>
             2 Person 2 <person2@example.com>
            """
        }
        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                // causing error to be thrown during package dump
                return "bad dump"
            }
            return ""
        }
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))
        try setAllVersionsUpdatedAt(app.db, updatedAt: .t0)
        do {
            let candidates = try await Package
                .fetchReAnalysisCandidates(app.db, before: cutoff, limit: 10)
            XCTAssertEqual(candidates.count, 1)
        }

        // MUT
        try await ReAnalyzeVersions.reAnalyzeVersions(client: app.client,
                                                      database: app.db,
                                                      logger: app.logger,
                                                      before: Current.date(),
                                                      refreshCheckouts: false,
                                                      limit: 10)

        // validate
        let candidates = try await Package
            .fetchReAnalysisCandidates(app.db, before: cutoff, limit: 10)
        XCTAssertEqual(candidates.count, 0)
    }

}


private func createVersion(_ db: Database,
                           _ package: Package,
                           updatedAt: Date) throws {
    let id = UUID()
    try Version(id: id, package: package).save(on: db).wait()
    try setUpdatedAt(db, versionId: id, updatedAt: updatedAt)
}


private func setUpdatedAt(_ db: Database,
                          versionId: Version.Id,
                          updatedAt: Date) throws {
    let db = db as! SQLDatabase
    try db.raw("""
        update versions set updated_at = to_timestamp(\(bind: updatedAt.timeIntervalSince1970))
        where id = \(bind: versionId)
        """)
        .run()
        .wait()
}


private func setAllVersionsUpdatedAt(_ db: Database, updatedAt: Date) throws {
    let db = db as! SQLDatabase
    try db.raw("""
        update versions set updated_at = to_timestamp(\(bind: updatedAt.timeIntervalSince1970))
        """)
        .run()
        .wait()
}
