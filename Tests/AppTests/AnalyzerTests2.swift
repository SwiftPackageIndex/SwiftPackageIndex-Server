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

import XCTest

@testable import App

import Dependencies
import Fluent
import NIOConcurrencyHelpers
import SPIManifest
import SnapshotTesting
import Vapor

@preconcurrency import ShellOut


class AnalyzerTests2: ParallelizedAppTestCase {

    @MainActor
    func test_analyze() async throws {
        // End-to-end test, where we mock at the shell command level (i.e. we
        // don't mock the git commands themselves to ensure we're running the
        // expected shell commands for the happy path.)
        let checkoutDir = QueueIsolated<String?>(nil)
        let firstDirCloned = QueueIsolated(false)
        let commands = QueueIsolated<[Command]>([])
        try await withDependencies {
            $0.date.now = .now
            $0.environment.allowSocialPosts = { true }
            $0.environment.loadSPIManifest = { path in
                if path.hasSuffix("foo-1") {
                    return .init(builder: .init(configs: [.init(documentationTargets: ["DocTarget"])]))
                } else {
                    return nil
                }
            }
            $0.fileManager.createDirectory = { @Sendable path, _, _ in checkoutDir.setValue(path) }
            $0.fileManager.fileExists = { @Sendable path in
                if let outDir = checkoutDir.value,
                   path == "\(outDir)/github.com-foo-1" { return firstDirCloned.value }
                // let the check for the second repo checkout path succeed to simulate pull
                if let outDir = checkoutDir.value,
                   path == "\(outDir)/github.com-foo-2" { return true }
                if path.hasSuffix("Package.swift") { return true }
                if path.hasSuffix("Package.resolved") { return true }
                return false
            }
            $0.git = .liveValue
            $0.httpClient.mastodonPost = { @Sendable _ in }
            $0.shell.run = { @Sendable cmd, path in
                let trimmedPath = path.replacingOccurrences(of: checkoutDir.value!, with: ".")
                commands.withValue {
                    $0.append(.init(command: cmd, path: trimmedPath)!)
                }
                if cmd.description.starts(with: "git clone") {
                    firstDirCloned.setValue(true)
                }
                if cmd == .gitListTags && path.hasSuffix("foo-1") {
                    return ["1.0.0", "1.1.1"].joined(separator: "\n")
                }
                if cmd == .gitListTags && path.hasSuffix("foo-2") {
                    return ["2.0.0", "2.1.0"].joined(separator: "\n")
                }
                if cmd == .swiftDumpPackage && path.hasSuffix("foo-1") {
                    return #"""
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
                }
                if cmd == .swiftDumpPackage && path.hasSuffix("foo-2") {
                    return #"""
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
                }

                // Git.revisionInfo (per ref - default branch & tags)
                // These return a string in the format `commit sha`-`timestamp (sec since 1970)`
                // We simply use `sha` for the sha (it bears no meaning) and a range of seconds
                // since 1970.
                // It is important the tags aren't created at identical times for tags on the same
                // package, or else we will collect multiple recent releases (as there is no "latest")
                if cmd == .gitRevisionInfo(reference: .tag(1, 0, 0)) { return "sha-0" }
                if cmd == .gitRevisionInfo(reference: .tag(1, 1, 1)) { return "sha-1" }
                if cmd == .gitRevisionInfo(reference: .tag(2, 0, 0)) { return "sha-2" }
                if cmd == .gitRevisionInfo(reference: .tag(2, 1, 0)) { return "sha-3" }
                if cmd == .gitRevisionInfo(reference: .branch("main")) { return "sha-4" }

                if cmd == .gitCommitCount { return "12" }
                if cmd == .gitFirstCommitDate { return "0" }
                if cmd == .gitLastCommitDate { return "4" }
                if cmd == .gitShortlog {
                    return "10\tPerson 1"
                }

                return ""
            }
        } operation: {
            // setup
            let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
            let pkgs = try await savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
            try await Repository(package: pkgs[0],
                                 defaultBranch: "main",
                                 name: "1",
                                 owner: "foo",
                                 releases: [
                                    .mock(description: "rel 1.0.0", tagName: "1.0.0")
                                 ],
                                 stars: 25).save(on: app.db)
            try await Repository(package: pkgs[1],
                                 defaultBranch: "main",
                                 name: "2",
                                 owner: "foo",
                                 stars: 100).save(on: app.db)

            // MUT
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      mode: .limit(10))

            // validation
            let outDir = try checkoutDir.value.unwrap()
            XCTAssert(outDir.hasSuffix("SPI-checkouts"), "unexpected checkout dir, was: \(outDir)")
            XCTAssertEqual(commands.value.count, 36)

            // Snapshot for each package individually to avoid ordering issues when
            // concurrent processing causes commands to interleave between packages.
            assertSnapshot(of: commands.value
                .filter { $0.path.hasSuffix("foo-1") }
                .map(\.description), as: .dump)
            assertSnapshot(of: commands.value
                .filter { $0.path.hasSuffix("foo-2") }
                .map(\.description), as: .dump)

            // validate versions
            // A bit awkward... create a helper? There has to be a better way?
            let pkg1 = try await Package.query(on: app.db).filter(by: urls[0].url).with(\.$versions).first()!
            XCTAssertEqual(pkg1.status, .ok)
            XCTAssertEqual(pkg1.processingStage, .analysis)
            XCTAssertEqual(pkg1.versions.map(\.packageName), ["foo-1", "foo-1", "foo-1"])
            let sortedVersions1 = pkg1.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
            XCTAssertEqual(sortedVersions1.map(\.reference.description), ["main", "1.0.0", "1.1.1"])
            XCTAssertEqual(sortedVersions1.map(\.latest), [.defaultBranch, nil, .release])
            XCTAssertEqual(sortedVersions1.map(\.releaseNotes), [nil, "rel 1.0.0", nil])

            let pkg2 = try await Package.query(on: app.db).filter(by: urls[1].url).with(\.$versions).first()!
            XCTAssertEqual(pkg2.status, .ok)
            XCTAssertEqual(pkg2.processingStage, .analysis)
            XCTAssertEqual(pkg2.versions.map(\.packageName), ["foo-2", "foo-2", "foo-2"])
            let sortedVersions2 = pkg2.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
            XCTAssertEqual(sortedVersions2.map(\.reference.description), ["main", "2.0.0", "2.1.0"])
            XCTAssertEqual(sortedVersions2.map(\.latest), [.defaultBranch, nil, .release])

            // validate products
            // (2 packages with 3 versions with 1 product each = 6 products)
            let products = try await Product.query(on: app.db).sort(\.$name).all()
            XCTAssertEqual(products.count, 6)
            _assertEquals(products, \.name, ["p1", "p1", "p1", "p2", "p2", "p2"])
            _assertEquals(products, \.targets,
                          [["t1"], ["t1"], ["t1"], ["t2"], ["t2"], ["t2"]])
            _assertEquals(products, \.type, [.executable, .executable, .executable, .library(.automatic), .library(.automatic), .library(.automatic)])

            // validate targets
            // (2 packages with 3 versions with 1 target each = 6 targets)
            let targets = try await Target.query(on: app.db).sort(\.$name).all()
            XCTAssertEqual(targets.map(\.name), ["t1", "t1", "t1", "t2", "t2", "t2"])

            // validate score
            XCTAssertEqual(pkg1.score, 30)
            XCTAssertEqual(pkg2.score, 40)

            // ensure stats, recent packages, and releases are refreshed
            let app = self.app!
            try await XCTAssertEqualAsync(try await Stats.fetch(on: app.db), .init(packageCount: 2))
            try await XCTAssertEqualAsync(try await RecentPackage.fetch(on: app.db).count, 2)
            try await XCTAssertEqualAsync(try await RecentRelease.fetch(on: app.db).count, 2)
        }
    }

}


private struct Command: CustomStringConvertible {
    var kind: Kind
    var path: String

    enum Kind {
        case checkout(String)
        case clean
        case clone(String)
        case commitCount
        case dumpPackage
        case fetch
        case firstCommitDate
        case lastCommitDate
        case getTags
        case hasBranch(String)
        case reset
        case resetToBranch(String)
        case shortlog
        case showDate
        case revisionInfo(String)
    }

    init?(command: ShellOutCommand, path: String) {
        let quotes = CharacterSet(charactersIn: "\"")
        let separator = "-"
        self.path = path
        switch command {
            case _ where command.description.starts(with: "git checkout"):
                let ref = String(command.description.split(separator: " ")[2])
                    .trimmingCharacters(in: quotes)
                self.kind = .checkout(ref)
            case .gitClean:
                self.kind = .clean
            case _ where command.description.starts(with: "git clone"):
                let url = String(command.description.split(separator: " ")
                                    .filter { $0.contains("https://") }
                                    .first!)
                self.kind = .clone(url)
            case .gitCommitCount:
                self.kind = .commitCount
            case .gitFetchAndPruneTags:
                self.kind = .fetch
            case .gitFirstCommitDate:
                self.kind = .firstCommitDate
            case _ where command.description.starts(with: "git show-ref --verify --quiet refs/heads/"):
                let branch = String(command.description.split(separator: "/").last!)
                self.kind = .hasBranch(branch)
            case .gitLastCommitDate:
                self.kind = .lastCommitDate
            case .gitListTags:
                self.kind = .getTags
            case .gitReset(hard: true):
                self.kind = .reset
            case _ where command.description.starts(with: "git reset origin"):
                let branch = String(command.description.split(separator: " ")[2])
                    .trimmingCharacters(in: quotes)
                self.kind = .resetToBranch(branch)
            case .gitShortlog:
                self.kind = .shortlog
            case _ where command.description.starts(with: #"git show -s --format=%ct"#):
                self.kind = .showDate
            case _ where command.description.starts(with: #"git log -n1 --format=tformat:"%H\#(separator)%ct""#):
                let ref = String(command.description.split(separator: " ").last!)
                    .trimmingCharacters(in: quotes)
                self.kind = .revisionInfo(ref)
            case .swiftDumpPackage:
                self.kind = .dumpPackage
            default:
                print("unmatched command: \(command.description)")
                return nil
        }
    }

    var description: String {
        switch self.kind {
            case .clean, .commitCount, .dumpPackage, .fetch, .firstCommitDate, .lastCommitDate, .getTags, .shortlog, .showDate, .reset:
                return "\(path): \(kind)"
            case .checkout(let ref):
                return "\(path): checkout \(ref)"
            case .clone(let url):
                return "\(path): clone \(url)"
            case let .hasBranch(branch):
                return "\(path): hasBranch \(branch)"
            case .resetToBranch(let branch):
                return "\(path): reset to \(branch)"
            case .revisionInfo(let ref):
                return "\(path): revisionInfo for \(ref)"
        }
    }
}


private enum TestError: Error {
    case simulatedCheckoutError
    case simulatedFetchError
    case unknownCommand
    case unspecifiedError
}


private extension String {
    static func packageDump(name: String) -> Self {
        #"""
        {
          "name": "\#(name)",
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
    }
}


// Temporary helper until we move to swift-testing
private func _assertEquals<Root, Value: Equatable>(_ values: [Root],
                                                 _ keyPath: KeyPath<Root, Value>,
                                                 _ expectations: [Value],
                                                 file: StaticString = #filePath,
                                                 line: UInt = #line) {
    XCTAssertEqual(values.map { $0[keyPath: keyPath] },
                   expectations,
                   "\(values.map { $0[keyPath: keyPath] }) not equal to \(expectations)",
                   file: (file), line: line)
}
