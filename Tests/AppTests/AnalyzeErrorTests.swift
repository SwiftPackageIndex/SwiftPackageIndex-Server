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
import ShellOut
import Testing
import Vapor


extension AllTests {
    @Suite struct AnalyzeErrorTests {
        let socialPosts = LockIsolated<[String]>([])
    }
}


// Test analysis error handling.
//
// This suite of tests ensures that errors in batch analysis do not impact processing
// of later packages.
//
// We analyze two packages where the first package is set up to encounter
// various error states and ensure the second package is successfully processed.
extension AllTests.AnalyzeErrorTests {
    var badPackageID: Package.Id { .id0 }
    var goodPackageID: Package.Id { .id1 }

    struct SimulatedError: Error { }

    func setup(_ app: Application) async throws {
        let pkgs = [
            Package(id: badPackageID,
                    url: "https://github.com/foo/1".url,
                    status: .ok,
                    processingStage: .ingestion),
            Package(id: goodPackageID,
                    url: "https://github.com/foo/2".url,
                    status: .ok,
                    processingStage: .ingestion),
        ]
        try await pkgs.save(on: app.db)

        try await [
            Repository(package: pkgs[0], defaultBranch: "main", name: "1", owner: "foo"),
            Repository(package: pkgs[1], defaultBranch: "main", name: "2", owner: "foo"),
        ].save(on: app.db)
    }

    @Test func analyze_refreshCheckout_failed() async throws {
        let capturingLogger = CapturingLogger()
        try await withApp(setup, defaultDependencies) { app in
            try await withDependencies {
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.logger = .testLogger(capturingLogger)
                $0.shell.run = { @Sendable cmd, path in
                    switch cmd {
                        case _ where cmd.description.contains("git clone https://github.com/foo/1"):
                            throw SimulatedError()

                        case .gitFetchAndPruneTags where path.hasSuffix("foo-1"):
                            throw SimulatedError()

                        default:
                            return try defaultShellRun(command: cmd, path: path)
                    }
                }
            } operation: {
                // MUT
                try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(10))

                // validate
                try await defaultValidation(app)
                try capturingLogger.logs.withValue { logs in
                    #expect(logs.count == 2)
                    let error = try logs.last.unwrap()
                    #expect(error.message.contains("refreshCheckout failed"), "was: \(error.message)")
                }
            }
        }
    }

    @Test func analyze_updateRepository_invalidPackageCachePath() async throws {
        let capturingLogger = CapturingLogger()
        try await withApp(setup, defaultDependencies) { app in
            try await withDependencies {
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.logger = .testLogger(capturingLogger)
            } operation: {
                // setup
                let pkg = try await Package.find(badPackageID, on: app.db).unwrap()
                // This may look weird but its currently the only way to actually create an
                // invalid package cache path - we need to mess up the package url.
                pkg.url = "foo/1"
                #expect(pkg.cacheDirectoryName == nil)
                try await pkg.save(on: app.db)

                // MUT
                try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(10))

                // validate
                try await defaultValidation(app)
                try capturingLogger.logs.withValue { logs in
                    #expect(logs.count == 2)
                    let error = try logs.last.unwrap()
                    #expect(error.message.contains( "AppError.invalidPackageCachePath"), "was: \(error.message)")
                }
            }
        }
    }

    @Test func analyze_getPackageInfo_gitCheckout_error() async throws {
        let capturingLogger = CapturingLogger()
        try await withApp(setup, defaultDependencies) { app in
            try await withDependencies {
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.logger = .testLogger(capturingLogger)
                $0.shell.run = { @Sendable cmd, path in
                    switch cmd {
                        case .gitCheckout(branch: "main", quiet: true) where path.hasSuffix("foo-1"):
                            throw SimulatedError()

                        default:
                            return try defaultShellRun(command: cmd, path: path)
                    }
                }
            } operation: {
                // MUT
                try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(10))

                // validate
                try await defaultValidation(app)
                try capturingLogger.logs.withValue { logs in
                    #expect(logs.count == 2)
                    let error = try logs.last.unwrap()
                    #expect(error.message.contains("AppError.noValidVersions"), "was: \(error.message)")
                }
            }
        }
    }

    @Test func analyze_dumpPackage_missing_manifest() async throws {
        let capturingLogger = CapturingLogger()
        try await withApp(setup, defaultDependencies) { app in
            try await withDependencies {
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable path in
                    if path.hasSuffix("github.com-foo-1/Package.swift") {
                        return false
                    }
                    return true
                }
                $0.logger = .testLogger(capturingLogger)
            } operation: {
                // MUT
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))

                // validate
                try await defaultValidation(app)
                try capturingLogger.logs.withValue { logs in
                    #expect(logs.count == 2)
                    let error = try logs.last.unwrap()
                    #expect(error.message.contains("AppError.noValidVersions"), "was: \(error.message)")
                }
            }
        }
    }

}


extension AllTests.AnalyzeErrorTests {
    // Cannot be a trait, because it references the member `socialPosts`
    var defaultDependencies: @Sendable (inout DependencyValues) async throws -> Void {
        {
            $0.date.now = .t0
            $0.environment.allowSocialPosts = { true }
            $0.git = .analyzeErrorTestsMock
            $0.httpClient.mastodonPost = { @Sendable msg in socialPosts.withValue { $0.append(msg) } }
            $0.shell.run = defaultShellRun(command:path:)
        }
    }
}


extension AllTests.AnalyzeErrorTests {
    func defaultValidation(_ app: Application) async throws {
        let versions = try await Version.query(on: app.db)
            .filter(\.$package.$id == goodPackageID)
            .all()
        #expect(versions.count == 2)
        #expect(versions.filter(\.isBranch).first?.latest == .defaultBranch)
        #expect(versions.filter(\.isTag).first?.latest == .release)
        socialPosts.withValue { posts in
            #expect(posts == [
            """
            ⬆️ foo just released foo-2 v1.2.3
            
            http://localhost:8080/foo/2#releases
            """
            ])
        }
    }
}


private func defaultShellRun(command: ShellOutCommand, path: String) throws -> String {
    switch command {
        case .swiftDumpPackage where path.hasSuffix("foo-1"):
            return packageSwift1

        case .swiftDumpPackage where path.hasSuffix("foo-2"):
            return packageSwift2

        default:
            return ""
    }
}


private extension GitClient {
    struct SetupError: Error { }
    static var analyzeErrorTestsMock: Self {
        .init(
            commitCount: { _ in 1 },
            firstCommitDate: { _ in .t0 },
            getTags: { checkoutDir in
                if checkoutDir.hasSuffix("foo-1") { return [] }
                if checkoutDir.hasSuffix("foo-2") { return [.tag(1, 2, 3)] }
                throw SetupError()
            },
            hasBranch: { _, _ in true },
            lastCommitDate: { _ in .t1 },
            revisionInfo: { ref, checkoutDir in
                if checkoutDir.hasSuffix("foo-1") { return .init(commit: "commit \(ref)", date: .t1) }
                if checkoutDir.hasSuffix("foo-2") { return .init(commit: "commit \(ref)", date: .t1) }
                throw SetupError()
            },
            shortlog: { _ in
                """
                1000\tPerson 1
                 871\tPerson 2
                 703\tPerson 3
                 360\tPerson 4
                 108\tPerson 5
                """
            }
        )
    }
}


private let packageSwift1 = #"""
                    {
                      "name": "foo-1",
                      "products": [
                        {
                          "name": "p1",
                          "targets": ["t1"],
                          "type": {
                            "executable": null
                          }
                        }
                      ],
                      "targets": [{"name": "t1", "type": "executable"}]
                    }
                    """#

private let packageSwift2 = #"""
                    {
                      "name": "foo-2",
                      "products": [
                        {
                          "name": "p2",
                          "targets": ["t2"],
                          "type": {
                            "library": ["automatic"]
                          }
                        }
                      ],
                      "targets": [{"name": "t2", "type": "regular"}]
                    }
                    """#

