// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import XCTest

@testable import App

import Fluent
import ShellOut


// Test analysis error handling.
//
// This suite of tests ensures that errors in batch analysis do not impact processing
// of later packages.
//
// We analyze two packages where the first package is set up to encounter
// various error states and ensure the second package is successfully processed.
final class AnalyzeErrorTests: AppTestCase {

    let badPackageID: Package.Id = .id0
    let goodPackageID: Package.Id = .id1

    actor Validator {
        static var reportedErrors = [Error]()
        static var tweets = [String]()

        static func reset() {
            reportedErrors = []
            tweets = []
        }
    }

    static var defaultShellRun: (ShellOutCommand, String) throws -> String = { cmd, path in
        switch cmd {
            case .swiftDumpPackage where path.hasSuffix("foo-1"):
                return packageSwift1

            case .swiftDumpPackage where path.hasSuffix("foo-2"):
                return packageSwift2

            default:
                return ""
        }
    }

    struct SetupError: Error { }
    struct SimulatedError: Error { }

    override func setUp() async throws {
        try await super.setUp()

        Validator.reset()

        // Silence logging
        app.logger = .init(label: "noop") { _ in SwiftLogNoOpLogHandler() }

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

        Current.git.commitCount = { _ in 1 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.showDate = { _, _ in .t1 }
        Current.git.getTags = { checkoutDir in
            if checkoutDir.hasSuffix("foo-1") { return [] }
            if checkoutDir.hasSuffix("foo-2") { return [.tag(1, 2, 3)] }
            throw SetupError()
        }
        Current.git.revisionInfo = { ref, checkoutDir in
            if checkoutDir.hasSuffix("foo-1") { return .init(commit: "commit \(ref)", date: .t1) }
            if checkoutDir.hasSuffix("foo-2") { return .init(commit: "commit \(ref)", date: .t1) }
            throw SetupError()
        }
        Current.git.shortlog = { _ in
            """
            1000  Person 1 <person1@example.com>
             871  Person 2 <person2@example.com>
             703  Person 3 <person5@example.com>
             360  Person 4 <person6@example.com>
             108  Person 5 <person7@example.com>
            """
        }

        Current.reportError = { _, _, error in
            Validator.reportedErrors.append(error)
            return self.app.eventLoopGroup.future()
        }

        Current.shell.run = Self.defaultShellRun

        Current.twitterPostTweet = { client, message in
            Validator.tweets.append(message)
            return self.app.eventLoopGroup.future()
        }
    }

    func test_analyze_refreshCheckout_failed() async throws {
        // setup
        Current.shell.run = { cmd, path in
            switch cmd {
                case _ where cmd.string.contains("git clone https://github.com/foo/1"):
                    throw SimulatedError()

                case .gitFetchAndPruneTags where path.hasSuffix("foo-1"):
                    throw SimulatedError()

                default:
                    return try Self.defaultShellRun(cmd, path)
            }
        }

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate
        try await defaultValidation()
        XCTAssertEqual(Validator.reportedErrors.count, 1)
        let error = try Validator.reportedErrors.first.unwrap().localizedDescription
        XCTAssertTrue(
            error.contains(
                #"""
                Analysis failed: refreshCheckout failed: Shell command failed:
                command: "git clone https://github.com/foo/1
                """#
            ),
            "was: \(error)"
        )
    }

    func test_analyze_updateRepository_invalidPackageCachePath() async throws {
        // setup
        let pkg = try await Package.find(badPackageID, on: app.db).unwrap()
        // This may look weird but its currently the only way to actually create an
        // invalid package cache path - we need to mess up the package url.
        pkg.url = "foo/1"
        XCTAssertNil(pkg.cacheDirectoryName)
        try await pkg.save(on: app.db)

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate
        try await defaultValidation()
        XCTAssertEqual(Validator.reportedErrors.count, 1)
        let error = try Validator.reportedErrors.first.unwrap().localizedDescription
        XCTAssertTrue(
            error.contains(
                #"""
                Invalid packge cache path: foo/1
                """#
            ),
            "was: \(error)"
        )
    }

    func test_analyze_getPackageInfo_gitCheckout_error() async throws {
        // setup
        Current.shell.run = { cmd, path in
            switch cmd {
                case .gitCheckout(branch: "main") where path.hasSuffix("foo-1"):
                    throw SimulatedError()

                default:
                    return try Self.defaultShellRun(cmd, path)
            }
        }

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate
        try await defaultValidation()
        XCTAssertEqual(Validator.reportedErrors.count, 1)
        let error = try Validator.reportedErrors.first.unwrap().localizedDescription
        XCTAssertTrue(
            error.contains(
                #"""
                No valid version found for package 'https://github.com/foo/1'
                """#
            ),
            "was: \(error)"
        )
    }

    func test_analyze_dumpPackage_missing_manifest() async throws {
        // setup
        Current.fileManager.fileExists = { path in
            if path.hasSuffix("github.com-foo-1/Package.swift") {
                return false
            }
            return true
        }

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate
        try await defaultValidation()
        XCTAssertEqual(Validator.reportedErrors.count, 1)
        let error = try Validator.reportedErrors.first.unwrap().localizedDescription
        print(error)
        XCTAssertTrue(
            error.contains(
                #"""
                No valid version found for package 'https://github.com/foo/1'
                """#
            ),
            "was: \(error)"
        )
    }


}


extension AnalyzeErrorTests {
    func defaultValidation() async throws {
        let versions = try await Version.query(on: app.db)
            .filter(\.$package.$id == goodPackageID)
            .all()
        XCTAssertEqual(versions.count, 2)
        XCTAssertEqual(versions.filter(\.isBranch).first?.latest, .defaultBranch)
        XCTAssertEqual(versions.filter(\.isTag).first?.latest, .release)
        XCTAssertEqual(Validator.tweets, [
            """
            ⬆️ foo just released foo-2 v1.2.3

            http://localhost:8080/foo/2#releases
            """
        ])
    }
}


let packageSwift1 = #"""
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

let packageSwift2 = #"""
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
