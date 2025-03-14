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


extension AllTests.ReAnalyzeVersionsTests {

    @Test func reAnalyzeVersions() async throws {
        // Basic end-to-end test
        try await withDependencies {
            $0.date.now = .t0
            $0.environment.allowSocialPosts = { true }
            $0.environment.loadSPIManifest = { _ in nil }
            $0.fileManager.fileExists = { @Sendable _ in true }
            $0.git.commitCount = { @Sendable _ in 12 }
            $0.git.firstCommitDate = { @Sendable _ in .t0 }
            $0.git.getTags = { @Sendable _ in [.tag(1, 2, 3)] }
            $0.git.hasBranch = { @Sendable _, _ in true }
            $0.git.lastCommitDate = { @Sendable _ in .t1 }
            $0.git.shortlog = { @Sendable _ in
                """
                10\tPerson 1
                 2\tPerson 2
                """
            }
            $0.httpClient.mastodonPost = { @Sendable _ in }
        } operation: {
            try await withApp { app in
                // setup
                // - package dump does not include toolsVersion, targets to simulate an "old version"
                // - run analysis to create existing version
                // - validate that initial state is reflected
                // - then change input data in fields that are affecting existing versions (which `analysis` is "blind" to)
                // - run analysis again to confirm "blindness"
                // - run re-analysis and confirm changes are now reflected
                let pkg = try await savePackage(on: app.db,
                                                "https://github.com/foo/1".url,
                                                processingStage: .ingestion)
                let repoId = UUID()
                try await Repository(id: repoId,
                                     package: pkg,
                                     defaultBranch: "main",
                                     name: "1",
                                     owner: "foo").save(on: app.db)

                try await withDependencies {
                    $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha", date: .t0) }
                    $0.shell.run = { @Sendable cmd, path in
                        if cmd.description.hasSuffix("swift package dump-package") {
                            return #"""
                            {
                              "name": "SPI-Server",
                              "products": [],
                              "targets": []
                            }
                            """#
                        }
                        return ""
                    }
                } operation: {
                    do {
                        // run initial analysis and assert initial state for versions
                        try await Analyze.analyze(client: app.client,
                                                  database: app.db,
                                                  mode: .limit(10))
                        let versions = try await Version.query(on: app.db)
                            .with(\.$targets)
                            .all()
                        #expect(versions.map(\.toolsVersion) == [nil, nil])
                        #expect(versions.map { $0.targets.map(\.name) } == [[], []])
                        #expect(versions.map(\.releaseNotes) == [nil, nil])
                    }

                    try await withDependencies {
                        // Update state that would normally not be affecting existing versions, effectively simulating the situation where we only started parsing it after versions had already been created
                        $0.shell.run = { @Sendable cmd, path in
                            if cmd.description.hasSuffix("swift package dump-package") {
                                return #"""
                        {
                          "name": "SPI-Server",
                          "products": [],
                          "targets": [{"name": "t1", "type": "regular"}],
                          "toolsVersion": {
                            "_version": "5.3"
                          }
                        }
                        """#
                            }
                            return ""
                        }
                        // also, update release notes to ensure mergeReleaseInfo is being called
                        let r = try await Repository.find(repoId, on: app.db).unwrap()
                        r.releases = [
                            .mock(description: "rel 1.2.3", tagName: "1.2.3")
                        ]
                        try await r.save(on: app.db)
                    } operation: {
                        do {  // assert running analysis again does not update existing versions
                            try await Analyze.analyze(client: app.client,
                                                      database: app.db,
                                                      mode: .limit(10))
                            let versions = try await Version.query(on: app.db)
                                .with(\.$targets)
                                .all()
                            #expect(versions.map(\.toolsVersion) == [nil, nil])
                            #expect(versions.map { $0.targets.map(\.name) } == [[], []])
                            #expect(versions.map(\.releaseNotes) == [nil, nil])
                            #expect(versions.map(\.docArchives) == [nil, nil])
                        }

                        // MUT
                        try await ReAnalyzeVersions.reAnalyzeVersions(client: app.client,
                                                                      database: app.db,
                                                                      before: Date.now,
                                                                      refreshCheckouts: false,
                                                                      limit: 10)

                        // validate that re-analysis has now updated existing versions
                        let versions = try await Version.query(on: app.db)
                            .with(\.$targets)
                            .sort(\.$createdAt)
                            .all()
                        #expect(versions.map(\.toolsVersion) == ["5.3", "5.3"])
                        #expect(versions.map { $0.targets.map(\.name) } == [["t1"], ["t1"]])
                        #expect(versions.compactMap(\.releaseNotes) == ["rel 1.2.3"])
                    }
                }
            }
        }
    }

    @Test func Package_fetchReAnalysisCandidates() async throws {
        // Three packages with two versions:
        // 1) both versions updated before cutoff -> candidate
        // 2) one version update before cutoff, one after -> candidate
        // 3) both version updated after cutoff -> not a candidate
        try await withApp { app in
            let cutoff = Date(timeIntervalSince1970: 2)
            do {
                let p = Package(url: "1")
                try await p.save(on: app.db)
                try await createVersion(app.db, p, updatedAt: .t0)
                try await createVersion(app.db, p, updatedAt: .t1)
            }
            do {
                let p = Package(url: "2")
                try await p.save(on: app.db)
                try await createVersion(app.db, p, updatedAt: .t1)
                try await createVersion(app.db, p, updatedAt: .t3)
            }
            do {
                let p = Package(url: "3")
                try await p.save(on: app.db)
                try await createVersion(app.db, p, updatedAt: .t3)
                try await createVersion(app.db, p, updatedAt: .t4)
            }

            // MUT
            let res = try await Package
                .fetchReAnalysisCandidates(app.db, before: cutoff, limit: 10)

            // validate
            #expect(res.map(\.model.url) == ["1", "2"])
        }
    }

    @Test func versionsUpdatedOnError() async throws {
        // Test to ensure versions are updated even if processing throws errors.
        // This is to ensure our candidate selection shrinks and we don't
        // churn over and over on failing versions.
        let cutoff = Date.t1
        try await withDependencies {
            $0.date.now = .t2
            $0.environment.loadSPIManifest = { _ in nil }
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
            $0.shell.run = { @Sendable cmd, path in
                if cmd == .swiftDumpPackage {
                    return #"""
                        {
                          "name": "foo-1",
                          "products": [],
                          "targets": [{"name": "t1", "type": "executable"}]
                        }
                        """#
                }
                return ""
            }
        } operation: {
            try await withApp { app in
                let pkg = try await savePackage(on: app.db,
                                                "https://github.com/foo/1".url,
                                                processingStage: .ingestion)
                try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))
                try await setAllVersionsUpdatedAt(app.db, updatedAt: .t0)
                do {
                    let candidates = try await Package
                        .fetchReAnalysisCandidates(app.db, before: cutoff, limit: 10)
                    #expect(candidates.count == 1)
                }
                
                try await withDependencies {
                    $0.shell.run = { @Sendable cmd, path in
                        if cmd == .swiftDumpPackage {
                            // simulate error during package dump
                            struct Error: Swift.Error { }
                            throw Error()
                        }
                        return ""
                    }
                } operation: {
                    // MUT
                    try await ReAnalyzeVersions.reAnalyzeVersions(client: app.client,
                                                                  database: app.db,
                                                                  before: Date.now,
                                                                  refreshCheckouts: false,
                                                                  limit: 10)
                    
                    // validate
                    let candidates = try await Package
                        .fetchReAnalysisCandidates(app.db, before: cutoff, limit: 10)
                    #expect(candidates.count == 0)
                }
            }
        }
    }

}


private func createVersion(_ db: Database,
                           _ package: Package,
                           updatedAt: Date) async throws {
    let id = UUID()
    try await Version(id: id, package: package).save(on: db)
    try await setUpdatedAt(db, versionId: id, updatedAt: updatedAt)
}


private func setUpdatedAt(_ db: Database,
                          versionId: Version.Id,
                          updatedAt: Date) async throws {
    let db = db as! SQLDatabase
    try await db.raw("""
        update versions set updated_at = to_timestamp(\(bind: updatedAt.timeIntervalSince1970))
        where id = \(bind: versionId)
        """)
        .run()
}


private func setAllVersionsUpdatedAt(_ db: Database, updatedAt: Date) async throws {
    let db = db as! SQLDatabase
    try await db.raw("""
        update versions set updated_at = to_timestamp(\(bind: updatedAt.timeIntervalSince1970))
        """)
        .run()
}
