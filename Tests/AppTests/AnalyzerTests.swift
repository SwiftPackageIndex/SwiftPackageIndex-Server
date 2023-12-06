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

import Fluent
import SPIManifest
import ShellOut
import SnapshotTesting
import Vapor


class AnalyzerTests: AppTestCase {

    @MainActor
    func test_analyze() async throws {
        // End-to-end test, where we mock at the shell command level (i.e. we
        // don't mock the git commands themselves to ensure we're running the
        // expected shell commands for the happy path.)
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        let pkgs = try savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
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

        let checkoutDir = QueueIsolated<String?>(nil)
        let commands = QueueIsolated<[Command]>([])
        let firstDirCloned = QueueIsolated(false)
        Current.fileManager.fileExists = { path in
            if let outDir = checkoutDir.value,
               path == "\(outDir)/github.com-foo-1" { return firstDirCloned.value }
            // let the check for the second repo checkout path succeed to simulate pull
            if let outDir = checkoutDir.value,
               path == "\(outDir)/github.com-foo-2" { return true }
            if path.hasSuffix("Package.swift") { return true }
            if path.hasSuffix("Package.resolved") { return true }
            return false
        }
        Current.fileManager.createDirectory = { path, _, _ in checkoutDir.setValue(path) }
        Current.git = .live
        Current.loadSPIManifest = { path in
            if path.hasSuffix("foo-1") {
                return .init(builder: .init(configs: [.init(documentationTargets: ["DocTarget"])]))
            } else {
                return nil
            }
        }
        Current.shell.run = { cmd, path in
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

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validation
        let outDir = try checkoutDir.value.unwrap()
        XCTAssert(outDir.hasSuffix("SPI-checkouts"), "unexpected checkout dir, was: \(outDir)")
        XCTAssertEqual(commands.value.count, 36)

        // Snapshot for each package individually to avoid ordering issues when
        // concurrent processing causes commands to interleave between packages.
        assertSnapshot(matching: commands.value
                        .filter { $0.path.hasSuffix("foo-1") }
                        .map(\.description), as: .dump)
        assertSnapshot(matching: commands.value
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
        assertEquals(products, \.name, ["p1", "p1", "p1", "p2", "p2", "p2"])
        assertEquals(products, \.targets,
                     [["t1"], ["t1"], ["t1"], ["t2"], ["t2"], ["t2"]])
        assertEquals(products, \.type, [.executable, .executable, .executable, .library(.automatic), .library(.automatic), .library(.automatic)])

        // validate targets
        // (2 packages with 3 versions with 1 target each = 6 targets)
        let targets = try await Target.query(on: app.db).sort(\.$name).all()
        XCTAssertEqual(targets.map(\.name), ["t1", "t1", "t1", "t2", "t2", "t2"])

        // validate score
        XCTAssertEqual(pkg1.score, 30)
        XCTAssertEqual(pkg2.score, 40)

        // ensure stats, recent packages, and releases are refreshed
        try await XCTAssertEqualAsync(try await Stats.fetch(on: app.db).get(), .init(packageCount: 2))
        try await XCTAssertEqualAsync(try await RecentPackage.fetch(on: app.db).count, 2)
        try await XCTAssertEqualAsync(try await RecentRelease.fetch(on: app.db).count, 2)
    }

    func test_analyze_version_update() async throws {
        // Ensure that new incoming versions update the latest properties and
        // move versions in case commits change. Tests both default branch commits
        // changing as well as a tag being moved to a different commit.
        // setup
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1".asGithubUrl.url, processingStage: .ingestion)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             name: "1",
                             owner: "foo").save(on: app.db)
        // add existing versions (to be reconciled)
        try await Version(package: pkg,
                          commit: "commit0",
                          commitDate: .t0,
                          latest: .defaultBranch,
                          packageName: "foo-1",
                          reference: .branch("main")).save(on: app.db)
        try await Version(package: pkg,
                          commit: "commit0",
                          commitDate: .t0,
                          latest: .release,
                          packageName: "foo-1",
                          reference: .tag(1, 0, 0)).save(on: app.db)

        Current.fileManager.fileExists = { _ in true }

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t2 }
        Current.git.getTags = { _ in [.tag(1, 0, 0), .tag(1, 1, 1)] }
        Current.git.hasBranch = { _, _ in true }
        Current.git.revisionInfo = { ref, _ in
            // simulate the following scenario:
            //   - main branch has moved from commit0 -> commit3 (timestamp t3)
            //   - 1.0.0 has been re-tagged (!) from commit0 -> commit1 (timestamp t1)
            //   - 1.1.1 has been added at commit2 (timestamp t2)
            switch ref {
                case _ where ref == .tag(1, 0, 0):
                    return .init(commit: "commit1", date: .t1)
                case _ where ref == .tag(1, 1, 1):
                    return .init(commit: "commit2", date: .t2)
                case .branch("main"):
                    return .init(commit: "commit3", date: .t3)
                default:
                    fatalError("unexpected reference: \(ref)")
            }
        }
        Current.git.shortlog = { _ in
            """
            10\tPerson 1
             2\tPerson 2
            """
        }

        Current.shell.run = { cmd, path in
            if cmd.description.hasSuffix("package dump-package") {
                return #"""
                    {
                      "name": "foo-1",
                      "products": [
                        {
                          "name": "p1",
                          "targets": [],
                          "type": {
                            "executable": null
                          }
                        }
                      ],
                      "targets": []
                    }
                    """#
            }
            return ""
        }

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate versions
        let p = try await Package.find(pkgId, on: app.db).unwrap()
        try await p.$versions.load(on: app.db)
        let versions = p.versions.sorted(by: { $0.commitDate < $1.commitDate })
        XCTAssertEqual(versions.map(\.commitDate), [.t1, .t2, .t3])
        XCTAssertEqual(versions.map(\.reference.description), ["1.0.0", "1.1.1", "main"])
        XCTAssertEqual(versions.map(\.latest), [nil, .release, .defaultBranch])
        XCTAssertEqual(versions.map(\.commit), ["commit1", "commit2", "commit3"])
    }

    func test_forward_progress_on_analysisError() async throws {
        // Ensure a package that fails analysis goes back to ingesting and isn't stuck in an analysis loop
        // setup
        do {
            let pkg = try savePackage(on: app.db, "https://github.com/foo/1", processingStage: .ingestion)
            try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        }

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.hasBranch = { _, _ in false }  // simulate analysis error via branch mismatch
        Current.git.shortlog = { _ in "" }

        // Ensure candidate selection is as expected
        try await XCTAssertEqualAsync( try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10).count, 0)
        try await XCTAssertEqualAsync( try await Package.fetchCandidates(app.db, for: .analysis, limit: 10).count, 1)

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // Ensure candidate selection is now zero for analysis
        // (and also for ingestion, as we're immediately after analysis)
        try await XCTAssertEqualAsync( try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10).count, 0)
        try await XCTAssertEqualAsync( try await Package.fetchCandidates(app.db, for: .analysis, limit: 10).count, 0)

        // Advance time beyond reIngestionDeadtime
        Current.date = { .now.addingTimeInterval(Constants.reIngestionDeadtime) }

        // Ensure candidate selection has flipped to ingestion
        try await XCTAssertEqualAsync( try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10).count, 1)
        try await XCTAssertEqualAsync( try await Package.fetchCandidates(app.db, for: .analysis, limit: 10).count, 0)
    }

    func test_package_status() async throws {
        // Ensure packages record success/error status
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        let pkgs = try savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
        for p in pkgs {
            try await Repository(package: p, defaultBranch: "main").save(on: app.db)
        }
        let lastUpdate = Date()

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.getTags = { _ in [.tag(1, 0, 0)] }
        Current.git.hasBranch = { _, _ in true }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }
        Current.git.shortlog = { _ in
            """
            10\tPerson 1
             2\tPerson 2
            """
        }

        Current.shell.run = { cmd, path in
            // first package fails
            if cmd.description.hasSuffix("swift package dump-package") && path.hasSuffix("foo-1") {
                return "bad data"
            }
            // second package succeeds
            if cmd.description.hasSuffix("swift package dump-package") && path.hasSuffix("foo-2") {
                return #"{ "name": "SPI-Server", "products": [], "targets": [] }"#
            }
            return ""
        }

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // assert packages have been updated
        let packages = try await Package.query(on: app.db).sort(\.$createdAt).all()
        packages.forEach { XCTAssert($0.updatedAt! > lastUpdate) }
        XCTAssertEqual(packages.map(\.status), [.noValidVersions, .ok])
    }

    func test_continue_on_exception() async throws {
        // Test to ensure exceptions don't interrupt processing
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        let pkgs = try savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
        for p in pkgs {
            try await Repository(package: p, defaultBranch: "main").save(on: app.db)
        }
        var checkoutDir: String? = nil

        Current.fileManager.fileExists = { path in
            if let outDir = checkoutDir, path == "\(outDir)/github.com-foo-1" { return true }
            if let outDir = checkoutDir, path == "\(outDir)/github.com-foo-2" { return true }
            if path.hasSuffix("Package.swift") { return true }
            return false
        }
        Current.fileManager.createDirectory = { path, _, _ in checkoutDir = path }

        Current.git = .live

        let refs: [Reference] = [.tag(1, 0, 0), .tag(1, 1, 1), .branch("main")]
        var mockResults: [ShellOutCommand: String] = [
            .gitListTags: refs.filter(\.isTag).map { "\($0)" }.joined(separator: "\n"),
            .gitCommitCount: "12",
            .gitFirstCommitDate: "0",
            .gitLastCommitDate: "1",
            .gitShortlog : """
                            10\tPerson 1
                             2\tPerson 2
                            """
        ]
        for (idx, ref) in refs.enumerated() {
            mockResults[.gitRevisionInfo(reference: ref)] = "sha-\(idx)"
        }

        let commands = QueueIsolated<[Command]>([])
        Current.shell.run = { cmd, path in
            commands.withValue {
                $0.append(.init(command: cmd, path: path)!)
            }

            if let result = mockResults[cmd] { return result }

            // simulate error in first package
            if cmd == .swiftDumpPackage {
                if path.hasSuffix("foo-1") {
                    // Simulate error when reading the manifest
                    struct Error: Swift.Error { }
                    throw Error()
                } else {
                    return #"""
                    {
                      "name": "foo-2",
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

            return ""
        }

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validation (not in detail, this is just to ensure command count is as expected)
        XCTAssertEqual(commands.value.count, 40, "was: \(dump(commands.value))")
        // 1 packages with 2 tags + 1 default branch each -> 3 versions (the other package fails)
        let versionCount = try await Version.query(on: app.db).count()
        XCTAssertEqual(versionCount, 3)
    }

    @MainActor
    func test_refreshCheckout() async throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".asGithubUrl.url)
        try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        Current.fileManager.fileExists = { _ in true }
        let commands = QueueIsolated<[String]>([])
        Current.shell.run = { cmd, path in
            // mask variable checkout
            let checkoutDir = Current.fileManager.checkoutsDirectory()
            commands.withValue {
                $0.append(cmd.description.replacingOccurrences(of: checkoutDir, with: "..."))
            }
            return ""
        }
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

        // MUT
        _ = try await Analyze.refreshCheckout(logger: app.logger, package: jpr)

        // validate
        assertSnapshot(matching: commands.value, as: .dump)
    }

    func test_updateRepository() async throws {
        // setup
        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.shortlog = { _ in
            """
            10\tPerson 1
             2\tPerson 2
            """
        }
        Current.shell.run = { cmd, _ in throw TestError.unknownCommand }
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        try await Repository(id: .id1, package: pkg, defaultBranch: "main").save(on: app.db)
        var jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

        do {  // MUT
            jpr = try await Analyze.updateRepository(on: app.db, package: jpr)
        }

        // validate
        do { // ensure changes are persisted
            let repo = try await Repository.find(.id1, on: app.db)
            XCTAssertEqual(repo?.commitCount, 12)
            XCTAssertEqual(repo?.firstCommitDate, .t0)
            XCTAssertEqual(repo?.lastCommitDate, .t1)
            XCTAssertEqual(repo?.authors, PackageAuthors(authors: [Author(name: "Person 1")], numberOfContributors: 1))
        }
        do { // ensure JPR relation is updated
            XCTAssertEqual(jpr.repository?.commitCount, 12)
            XCTAssertEqual(jpr.repository?.firstCommitDate, .t0)
            XCTAssertEqual(jpr.repository?.lastCommitDate, .t1)
            XCTAssertEqual(jpr.repository?.authors, PackageAuthors(authors: [Author(name: "Person 1")],
                                                                   numberOfContributors: 1))
        }
    }

    func test_getIncomingVersions() async throws {
        // setup
        Current.git.getTags = { _ in [.tag(1, 2, 3)] }
        Current.git.hasBranch = { _, _ in true }
        Current.git.revisionInfo = { ref, _ in .init(commit: "sha-\(ref)", date: .t0) }
        do {
            let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
            try await pkg.save(on: app.db)
            try await Repository(id: .id1, package: pkg, defaultBranch: "main").save(on: app.db)
        }
        let pkg = try await Package.fetchCandidate(app.db, id: .id0)

        // MUT
        let versions = try await Analyze.getIncomingVersions(client: app.client, logger: app.logger, package: pkg)

        // validate
        XCTAssertEqual(versions.map(\.commit).sorted(), ["sha-1.2.3", "sha-main"])
    }

    func test_getIncomingVersions_default_branch_mismatch() async throws {
        // setup
        Current.git.hasBranch = { _, _ in false}  // simulate branch mismatch
        do {
            let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
            try await pkg.save(on: app.db)
            try await Repository(id: .id1, package: pkg, defaultBranch: "main").save(on: app.db)
        }
        let pkg = try await Package.fetchCandidate(app.db, id: .id0)

        // MUT
        do {
            _ = try await Analyze.getIncomingVersions(client: app.client, logger: app.logger, package: pkg)
            XCTFail("expected an analysisError to be thrown")
        } catch let AppError.analysisError(.some(pkgId), msg) {
            // validate
            XCTAssertEqual(pkgId, .id0)
            XCTAssertEqual(msg, "Default branch 'main' does not exist in checkout")
        }
    }
    
    func test_getIncomingVersions_no_default_branch() async throws {
        // setup
        // saving Package without Repository means it has no default branch
        try await Package(id: .id0, url: "1".asGithubUrl.url).save(on: app.db)
        let pkg = try await Package.fetchCandidate(app.db, id: .id0)

        // MUT
        do {
            _ = try await Analyze.getIncomingVersions(client: app.client, logger: app.logger, package: pkg)
            XCTFail("expected an analysisError to be thrown")
        } catch let AppError.analysisError(.some(pkgId), msg) {
            // validate
            XCTAssertEqual(pkgId, .id0)
            XCTAssertEqual(msg, "Package must have default branch")
        }
    }

    func test_diffVersions() async throws {
        //setup
        Current.git.getTags = { _ in [.tag(1, 2, 3)] }
        Current.git.hasBranch = { _, _ in true }
        Current.git.revisionInfo = { ref, _ in
            if ref == .branch("main") { return . init(commit: "sha.main", date: .t0) }
            if ref == .tag(1, 2, 3) { return .init(commit: "sha.1.2.3", date: .t1) }
            fatalError("unknown ref: \(ref)")
        }
        Current.shell.run = { cmd, _ in throw TestError.unknownCommand }
        let pkgId = UUID()
        do {
            let pkg = Package(id: pkgId, url: "1".asGithubUrl.url)
            try await pkg.save(on: app.db)
            try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        }
        let pkg = try await Package.fetchCandidate(app.db, id: pkgId)

        // MUT
        let delta = try await Analyze.diffVersions(client: app.client,
                                                   logger: app.logger,
                                                   transaction: app.db,
                                                   package: pkg)

        // validate
        assertEquals(delta.toAdd, \.reference,
                     [.branch("main"), .tag(1, 2, 3)])
        assertEquals(delta.toAdd, \.commit, ["sha.main", "sha.1.2.3"])
        assertEquals(delta.toAdd, \.commitDate,
                     [Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 1)])
        assertEquals(delta.toAdd, \.url, [
            "https://github.com/foo/1/tree/main",
            "https://github.com/foo/1/releases/tag/1.2.3"
        ])
        XCTAssertEqual(delta.toDelete, [])
    }

    func test_mergeReleaseInfo() async throws {
        // setup
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg, releases:[
            .mock(description: "rel 1.2.3", publishedAt: 1, tagName: "1.2.3"),
            .mock(description: "rel 2.0.0", publishedAt: 2, tagName: "2.0.0"),
            // 2.1.0 release note is missing on purpose
            .mock(description: "rel 2.2.0", isDraft: true, publishedAt: 3, tagName: "2.2.0"),
            .mock(description: "rel 2.3.0", publishedAt: 4, tagName: "2.3.0", url: "some url"),
            .mock(description: nil, tagName: "2.4.0")
        ]).save(on: app.db)
        let versions: [Version] = try [
            (Date(timeIntervalSince1970: 0), Reference.tag(1, 2, 3)),
            (Date(timeIntervalSince1970: 1), Reference.tag(2, 0, 0)),
            (Date(timeIntervalSince1970: 2), Reference.tag(2, 1, 0)),
            (Date(timeIntervalSince1970: 3), Reference.tag(2, 2, 0)),
            (Date(timeIntervalSince1970: 4), Reference.tag(2, 3, 0)),
            (Date(timeIntervalSince1970: 5), Reference.tag(2, 4, 0)),
            (Date(timeIntervalSince1970: 6), Reference.branch("main")),
        ].map { date, ref in
            let v = try Version(id: UUID(),
                                package: pkg,
                                commitDate: date,
                                reference: ref)
            try v.save(on: app.db).wait()
            return v
        }
        let jpr = try await Package.fetchCandidate(app.db, id: .id0)

        // MUT
        Analyze.mergeReleaseInfo(package: jpr, into: versions)

        // validate
        let sortedResults = versions.sorted { $0.commitDate < $1.commitDate }
        XCTAssertEqual(sortedResults.map(\.releaseNotes),
                       ["rel 1.2.3", "rel 2.0.0", nil, nil, "rel 2.3.0", nil, nil])
        XCTAssertEqual(sortedResults.map(\.url),
                       ["", "", nil, nil, "some url", "", nil])
        XCTAssertEqual(sortedResults.map(\.publishedAt),
                       [Date(timeIntervalSince1970: 1),
                        Date(timeIntervalSince1970: 2),
                        nil, nil,
                        Date(timeIntervalSince1970: 4),
                        nil, nil])
    }

    func test_applyVersionDelta() async throws {
        // Ensure the existing default doc archives are preserved when replacing the default branch version
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2288
        // setup
        let pkg = Package(id: .id0, url: "1")
        try await pkg.save(on: app.db)
        let oldMain = try Version(package: pkg, commit: "1", docArchives: [.init(name: "foo", title: "Foo")], reference: .branch("main"))
        try await oldMain.save(on: app.db)
        let newMain = try Version(package: pkg, commit: "2", reference: .branch("main"))

        // MUT
        try await Analyze.applyVersionDelta(on: app.db, delta: .init(
            toAdd: [newMain],
            toDelete: [oldMain],
            toKeep: []
        ))

        do {  // validate
            try await XCTAssertEqualAsync(try await Version.query(on: app.db).count(), 1)
            let v = try await XCTUnwrapAsync(await Version.query(on: app.db).first())
            XCTAssertEqual(v.docArchives, [.init(name: "foo", title: "Foo")])
        }
    }

    func test_applyVersionDelta_newRelease() async throws {
        // Ensure the existing default doc archives aren't copied over to a new release
        // setup
        let pkg = Package(id: .id0, url: "1")
        try await pkg.save(on: app.db)
        let main = try Version(package: pkg, commit: "1", docArchives: [.init(name: "foo", title: "Foo")], reference: .branch("main"))
        try await main.save(on: app.db)
        let newTag = try Version(package: pkg, commit: "2", reference: .branch("main"))

        // MUT
        try await Analyze.applyVersionDelta(on: app.db, delta: .init(
            toAdd: [newTag],
            toDelete: [],
            toKeep: [main]
        ))

        do {  // validate
            try await XCTAssertEqualAsync(try await Version.query(on: app.db).count(), 2)
            let versions = try await XCTUnwrapAsync(await Version.query(on: app.db).sort(\.$commit).all())
            XCTAssertEqual(versions[0].docArchives, [.init(name: "foo", title: "Foo")])
            XCTAssertEqual(versions[1].docArchives, nil)
        }
    }

    func test_getPackageInfo() async throws {
        // Tests getPackageInfo(package:version:)
        // setup
        let commands = QueueIsolated<[String]>([])
        Current.shell.run = { cmd, _ in
            commands.withValue {
                $0.append(cmd.description)
            }
            if cmd == .swiftDumpPackage {
                return #"{ "name": "SPI-Server", "products": [], "targets": [] }"#
            }
            return ""
        }
        let pkg = try savePackage(on: app.db, "https://github.com/foo/1")
        try await Repository(package: pkg, name: "1", owner: "foo").save(on: app.db)
        let version = try Version(id: UUID(), package: pkg, reference: .tag(.init(0, 4, 2)))
        try await version.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

        // MUT
        let info = try await Analyze.getPackageInfo(package: jpr, version: version)

        // validation
        XCTAssertEqual(commands.value, [
            "git checkout 0.4.2 --quiet",
            "swift package dump-package"
        ])
        XCTAssertEqual(info.packageManifest.name, "SPI-Server")
    }

    func test_updateVersion() throws {
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        let version = try Version(package: pkg, reference: .branch("main"))
        let manifest = Manifest(name: "foo",
                                platforms: [.init(platformName: .ios, version: "11.0"),
                                            .init(platformName: .macos, version: "10.10")],
                                products: [],
                                swiftLanguageVersions: ["1", "2", "3.0.0"],
                                targets: [],
                                toolsVersion: .init(version: "5.0.0"))
        let spiManifest = try SPIManifest.Manifest(yml: """
            version: 1
            builder:
              configs:
              - platform: macosSpm
                scheme: Some scheme
            """)

        // MUT
        _ = try Analyze.updateVersion(on: app.db,
                                      version: version,
                                      packageInfo: .init(packageManifest: manifest,
                                                         spiManifest: spiManifest)).wait()

        // read back and validate
        let v = try Version.query(on: app.db).first().wait()!
        XCTAssertEqual(v.packageName, "foo")
        XCTAssertEqual(v.resolvedDependencies?.map(\.packageName), nil)
        XCTAssertEqual(v.swiftVersions, ["1", "2", "3.0.0"].asSwiftVersions)
        XCTAssertEqual(v.supportedPlatforms, [.ios("11.0"), .macos("10.10")])
        XCTAssertEqual(v.toolsVersion, "5.0.0")
        XCTAssertEqual(v.spiManifest, spiManifest)
    }

    func test_createProducts() throws {
        // setup
        let p = Package(id: UUID(), url: "1")
        let v = try Version(id: UUID(), package: p, packageName: "1", reference: .tag(.init(1, 0, 0)))
        let m = Manifest(name: "1",
                         products: [.init(name: "p1",
                                          targets: ["t1", "t2"],
                                          type: .library(.automatic)),
                                    .init(name: "p2",
                                          targets: ["t3", "t4"],
                                          type: .executable)],
                         targets: [],
                         toolsVersion: .init(version: "5.0.0"))
        try p.save(on: app.db).wait()
        try v.save(on: app.db).wait()

        // MUT
        try Analyze.createProducts(on: app.db, version: v, manifest: m).wait()

        // validation
        let products = try Product.query(on: app.db).sort(\.$createdAt).all().wait()
        XCTAssertEqual(products.map(\.name), ["p1", "p2"])
        XCTAssertEqual(products.map(\.targets), [["t1", "t2"], ["t3", "t4"]])
        XCTAssertEqual(products.map(\.type), [.library(.automatic), .executable])
    }

    func test_createTargets() throws {
        // setup
        let p = Package(id: UUID(), url: "1")
        let v = try Version(id: UUID(), package: p, packageName: "1", reference: .tag(.init(1, 0, 0)))
        let m = Manifest(name: "1",
                         products: [],
                         targets: [.init(name: "t1", type: .regular), .init(name: "t2", type: .executable)],
                         toolsVersion: .init(version: "5.0.0"))
        try p.save(on: app.db).wait()
        try v.save(on: app.db).wait()

        // MUT
        try Analyze.createTargets(on: app.db, version: v, manifest: m).wait()

        // validation
        let targets = try Target.query(on: app.db).sort(\.$createdAt).all().wait()
        XCTAssertEqual(targets.map(\.name), ["t1", "t2"])
        XCTAssertEqual(targets.map(\.type), [.regular, .executable])
    }

    func test_updatePackages() async throws {
        // setup
        let packages = try savePackages(on: app.db, ["1", "2"].asURLs)
            .map(Joined<Package, Repository>.init(model:))
        let results: [Result<Joined<Package, Repository>, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.noValidVersions(try packages[0].model.requireID(), "1")),
            .success(packages[1])
        ]

        // MUT
        try await updatePackages(client: app.client,
                                 database: app.db,
                                 logger: app.logger,
                                 results: results,
                                 stage: .analysis)

        // validate
        do {
            let packages = try await Package.query(on: app.db).sort(\.$url).all()
            assertEquals(packages, \.status, [.noValidVersions, .ok])
            assertEquals(packages, \.processingStage, [.analysis, .analysis])
        }
    }

    func test_issue_29() async throws {
        // Regression test for issue 29
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/29
        // setup
        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.getTags = { _ in [.tag(1, 0, 0), .tag(2, 0, 0)] }
        Current.git.hasBranch = { _, _ in true }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }
        Current.git.shortlog = { _ in
            """
            10\tPerson 1
             2\tPerson 2
            """
        }
        Current.shell.run = { cmd, path in
            if cmd.description.hasSuffix("swift package dump-package") {
                return #"""
                    {
                      "name": "foo",
                      "products": [
                        {
                          "name": "p1",
                          "targets": [],
                          "type": {
                            "executable": null
                          }
                        },
                        {
                          "name": "p2",
                          "targets": [],
                          "type": {
                            "executable": null
                          }
                        }
                      ],
                      "targets": []
                    }
                    """#
            }
            return ""
        }
        let pkgs = try savePackages(on: app.db, ["1", "2"].asGithubUrls.asURLs, processingStage: .ingestion)
        try pkgs.forEach {
            try Repository(package: $0, defaultBranch: "main").save(on: app.db).wait()
        }

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validation
        // 1 version for the default branch + 2 for the tags each = 6 versions
        // 2 products per version = 12 products
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 6)
        XCTAssertEqual(try Product.query(on: app.db).count().wait(), 12)
    }

    @MainActor
    func test_issue_70() async throws {
        // Certain git commands fail when index.lock exists
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/70
        // setup
        try savePackage(on: app.db, "1".asGithubUrl.url, processingStage: .ingestion)
        let pkgs = try await Package.fetchCandidates(app.db, for: .analysis, limit: 10)

        let checkoutDir = Current.fileManager.checkoutsDirectory()
        // claim every file exists, including our ficticious 'index.lock' for which
        // we want to trigger the cleanup mechanism
        Current.fileManager.fileExists = { path in true }

        let commands = QueueIsolated<[String]>([])
        Current.shell.run = { cmd, path in
            commands.withValue {
                let c = cmd.description.replacingOccurrences(of: checkoutDir, with: "...")
                $0.append(c)
            }
            return ""
        }

        // MUT
        let res = await pkgs.mapAsync { pkg in
            await Result {
                try await Analyze.refreshCheckout(logger: self.app.logger, package: pkg)
            }
        }

        // validation
        XCTAssertEqual(res.map(\.isSuccess), [true])
        assertSnapshot(matching: commands.value, as: .dump)
    }

    @MainActor
    func test_issue_498() async throws {
        // git checkout can still fail despite git reset --hard + git clean
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/498
        // setup
        try savePackage(on: app.db, "1".asGithubUrl.url, processingStage: .ingestion)
        let pkgs = try await Package.fetchCandidates(app.db, for: .analysis, limit: 10)

        let checkoutDir = Current.fileManager.checkoutsDirectory()
        // claim every file exists, including our ficticious 'index.lock' for which
        // we want to trigger the cleanup mechanism
        Current.fileManager.fileExists = { path in true }

        let commands = QueueIsolated<[String]>([])
        Current.shell.run = { cmd, path in
            commands.withValue {
                let c = cmd.description.replacingOccurrences(of: checkoutDir, with: "${checkouts}")
                $0.append(c)
            }
            if cmd == .gitCheckout(branch: "master") {
                throw TestError.simulatedCheckoutError
            }
            return ""
        }

        // MUT
        let res = await pkgs.mapAsync { pkg in
            await Result {
                try await Analyze.refreshCheckout(logger: self.app.logger, package: pkg)
            }
        }

        // validation
        XCTAssertEqual(res.map(\.isSuccess), [true])
        assertSnapshot(matching: commands.value, as: .dump)
    }

    func test_dumpPackage_5_4() async throws {
        // Test parsing a Package.swift that requires a 5.4 toolchain
        // NB: If this test fails on macOS make sure xcode-select -p
        // points to the correct version of Xcode!
        // setup
        Current.fileManager = .live
        Current.shell = .live
        try await withTempDir { tempDir in
            let fixture = fixturesDirectory()
                .appendingPathComponent("5.4-Package-swift").path
            let fname = tempDir.appending("/Package.swift")
            try await ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
            let m = try await Analyze.dumpPackage(at: tempDir)
            XCTAssertEqual(m.name, "VisualEffects")
        }
    }

    func test_dumpPackage_5_5() async throws {
        // Test parsing a Package.swift that requires a 5.5 toolchain
        // NB: If this test fails on macOS make sure xcode-select -p
        // points to the correct version of Xcode!
        // See also https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1441
        // setup
        Current.fileManager = .live
        Current.shell = .live
        try await withTempDir { tempDir in
            let fixture = fixturesDirectory()
                .appendingPathComponent("5.5-Package-swift").path
            let fname = tempDir.appending("/Package.swift")
            try await ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
            let m = try await Analyze.dumpPackage(at: tempDir)
            XCTAssertEqual(m.name, "Firestarter")
        }
    }

    func test_dumpPackage_5_9_macro_target() async throws {
        // Test parsing a 5.9 Package.swift with a macro target
        // NB: If this test fails on macOS make sure xcode-select -p
        // points to the correct version of Xcode!
        // setup
        Current.fileManager = .live
        Current.shell = .live
        try await withTempDir { tempDir in
            let fixture = fixturesDirectory()
                .appendingPathComponent("5.9-Package-swift").path
            let fname = tempDir.appending("/Package.swift")
            try await ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
            let m = try await Analyze.dumpPackage(at: tempDir)
            XCTAssertEqual(m.name, "StaticMemberIterable")
        }
    }

    func test_dumpPackage_format() async throws {
        // Test dump-package JSON format
        // We decode this JSON output in a number of places and if there are changes in output
        // (which depend on the compiler version), the respective decoders need to be updated.
        // If the format has changed, i.e. this test fails, make sure to review the decoders
        // in (at least) these places:
        // - SPI-Server: App.Manifest
        // - Validator: ValidatorCore.Package
        // - PackageList: validate.swift - Package
        // NB: If this test fails on macOS make sure xcode-select -p
        // points to the correct version of Xcode!
        // setup
        Current.fileManager = .live
        Current.shell = .live
        try await withTempDir { tempDir in
            let fixture = fixturesDirectory()
                .appendingPathComponent("5.9-Package-swift").path
            let fname = tempDir.appending("/Package.swift")
            try await ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
            var json = try await Current.shell.run(command: .swiftDumpPackage, at: tempDir)
            do {  // "root" references tempDir's absolute path - replace it to make the test stable
                if var obj = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
                   var packageKind = obj["packageKind"] as? [String: Any] {
                    packageKind["root"] = ["<tempdir>"]
                    obj["packageKind"] = packageKind
                    let data = try JSONSerialization.data(withJSONObject: obj,
                                                          options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
                    json = String(decoding: data, as: UTF8.self)
                }
            }
#if os(macOS)
            assertSnapshot(matching: json, as: .init(pathExtension: "json", diffing: .lines), named: "macos")
#elseif os(Linux)
            assertSnapshot(matching: json, as: .init(pathExtension: "json", diffing: .lines), named: "linux")
#endif
        }
    }

    func test_issue_577() async throws {
        // Duplicate "latest release" versions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/577
        // setup
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1")
        try await pkg.save(on: app.db)
        try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        // existing "latest release" version
        try await Version(package: pkg, latest: .release, packageName: "foo", reference: .tag(1, 2, 3))
            .save(on: app.db)
        // new, not yet considered release version
        try await Version(package: pkg, packageName: "foo", reference: .tag(1, 3, 0))
            .save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

        // MUT
        let versions = try await Analyze.updateLatestVersions(on: app.db, package: jpr)

        // validate
        do {  // refetch package to ensure changes are persisted
            let versions = versions.sorted(by: { $0.createdAt! < $1.createdAt! })
            XCTAssertEqual(versions.map(\.reference.description), ["1.2.3", "1.3.0"])
            XCTAssertEqual(versions.map(\.latest), [nil, .release])
        }
    }

    @MainActor
    func test_issue_693() async throws {
        // Handle moved tags
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/693
        // setup
        do {
            let pkg = try savePackage(on: app.db, id: .id0, "1".asGithubUrl.url)
            try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        }
        let pkg = try await Package.fetchCandidate(app.db, id: .id0)
        Current.fileManager.fileExists = { _ in true }
        let commands = QueueIsolated<[String]>([])
        Current.shell.run = { cmd, _ in
            commands.withValue {
                // mask variable checkout
                let checkoutDir = Current.fileManager.checkoutsDirectory()
                $0.append(cmd.description.replacingOccurrences(of: checkoutDir, with: "..."))
            }
            if cmd == .gitFetchAndPruneTags { throw TestError.simulatedFetchError }
            return ""
        }

        // MUT
        _ = try await Analyze.refreshCheckout(logger: app.logger, package: pkg)

        // validate
        assertSnapshot(matching: commands.value, as: .dump)
    }

    func test_updateLatestVersions() async throws {
        // setup
        func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }
        let pkg = Package(id: UUID(), url: "1")
        try await pkg.save(on: app.db)
        try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        try await Version(package: pkg, commitDate: t(2), packageName: "foo", reference: .branch("main"))
            .save(on: app.db)
        try await Version(package: pkg, commitDate: t(0), packageName: "foo", reference: .tag(1, 2, 3))
            .save(on: app.db)
        try await Version(package: pkg, commitDate: t(1), packageName: "foo", reference: .tag(2, 0, 0, "rc1"))
            .save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

        // MUT
        let versions = try await Analyze.updateLatestVersions(on: app.db, package: jpr)

        // validate
        do {
            try await pkg.$versions.load(on: app.db)
            let versions = versions.sorted(by: { $0.createdAt! < $1.createdAt! })
            XCTAssertEqual(versions.map(\.reference.description), ["main", "1.2.3", "2.0.0-rc1"])
            XCTAssertEqual(versions.map(\.latest), [.defaultBranch, .release, .preRelease])
        }
    }

    func test_updateLatestVersions_old_beta() async throws {
        // Test to ensure outdated betas aren't picked up as latest versions
        // and that faulty db content (outdated beta marked as latest pre-release)
        // is correctly reset.
        // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/188
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try await pkg.save(on: app.db)
        try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
        try await Version(package: pkg,
                    latest: .defaultBranch,
                    packageName: "foo",
                    reference: .branch("main"))
            .save(on: app.db)
        try await Version(package: pkg,
                    latest: .release,
                    packageName: "foo",
                    reference: .tag(2, 0, 0))
            .save(on: app.db)
        try await Version(package: pkg,
                    latest: .preRelease,  // this should have been nil - ensure it's reset
                    packageName: "foo",
                    reference: .tag(2, 0, 0, "rc1"))
            .save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

        // MUT
        let versions = try await Analyze.updateLatestVersions(on: app.db, package: jpr)

        // validate
        XCTAssertEqual(versions.map(\.reference.description), ["main", "2.0.0", "2.0.0-rc1"])
        XCTAssertEqual(versions.map(\.latest), [.defaultBranch, .release, nil])
    }

    func test_issue_914() async throws {
        // Ensure we handle 404 repos properly
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/914
        // setup
        do {
            let url = "1".asGithubUrl.url
            let pkg = Package.init(url: url, processingStage: .ingestion)
            try await pkg.save(on: app.db)
            Current.fileManager.fileExists = { path in
                if path.hasSuffix("github.com-foo-1") { return false }
                return true
            }
            let repoDir = try Current.fileManager.checkoutsDirectory() + "/" + XCTUnwrap(pkg.cacheDirectoryName)
            struct ShellOutError: Error {}
            Current.shell.run = { cmd, path in
                if cmd == .gitClone(url: url, to: repoDir) {
                    throw ShellOutError()
                }
                fatalError("should not be reached")
            }
        }
        let lastUpdated = Date()

        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate
        let pkg = try await Package.query(on: app.db).first().unwrap()
        XCTAssertTrue(pkg.updatedAt! > lastUpdated)
        XCTAssertEqual(pkg.status, .analysisFailed)
    }

    func test_trimCheckouts() throws {
        // setup
        Current.fileManager.checkoutsDirectory = { "/checkouts" }
        Current.fileManager.contentsOfDirectory = { _ in ["foo", "bar"] }
        Current.fileManager.attributesOfItem = { path in
            [
                "/checkouts/foo": [FileAttributeKey.modificationDate: Current.date().adding(days: -31)],
                "/checkouts/bar": [FileAttributeKey.modificationDate: Current.date().adding(days: -29)],
            ][path]!
        }
        var removedPaths = [String]()
        Current.fileManager.removeItem = { removedPaths.append($0) }

        // MUT
        try Analyze.trimCheckouts()

        // validate
        XCTAssertEqual(removedPaths, ["/checkouts/foo"])
    }

    func test_issue_2571_tags() async throws {
        // Ensure bad git commands do not delete existing tag revisions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2571
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1".asGithubUrl.url, processingStage: .ingestion)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             name: "1",
                             owner: "foo").save(on: app.db)
        try await Version(package: pkg,
                          commit: "commit0",
                          commitDate: .t0,
                          latest: .defaultBranch,
                          packageName: "foo-1",
                          reference: .branch("main")).save(on: app.db)
        try await Version(package: pkg,
                          commit: "commit0",
                          commitDate: .t0,
                          latest: .release,
                          packageName: "foo-1",
                          reference: .tag(1, 0, 0)).save(on: app.db)
        Current.fileManager.fileExists = { _ in true }
        Current.git.commitCount = { _ in 2 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.hasBranch = { _, _ in true }
        Current.git.lastCommitDate = { _ in .t1 }
        struct Error: Swift.Error { }
        Current.git.shortlog = { _ in
            """
            1\tPerson 1
            1\tPerson 2
            """
        }
        Current.shell.run = { cmd, path in "" }

        do {  // first scenario: bad getTags
            Current.git.getTags = { _ in throw Error() }
            Current.git.revisionInfo = { _, _ in .init(commit: "", date: .t1) }

            // MUT
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      logger: app.logger,
                                      mode: .limit(1))

            // validate versions
            let p = try await Package.find(pkgId, on: app.db).unwrap()
            try await p.$versions.load(on: app.db)
            let versions = p.versions.map(\.reference.description).sorted()
            XCTAssertEqual(versions, ["1.0.0", "main"])
        }

        do {  // second scenario: revisionInfo throws
            Current.git.getTags = { _ in [.tag(1, 0, 0)] }
            Current.git.revisionInfo = { _, _ in throw Error() }

            // MUT
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      logger: app.logger,
                                      mode: .limit(1))

            // validate versions
            let p = try await Package.find(pkgId, on: app.db).unwrap()
            try await p.$versions.load(on: app.db)
            let versions = p.versions.map(\.reference.description).sorted()
            XCTAssertEqual(versions, ["1.0.0", "main"])
        }

        do {  // second scenario: gitTags throws
            Current.git.getTags = { _ in throw Error() }
            Current.git.revisionInfo = { _, _ in .init(commit: "", date: .t1) }

            // MUT
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      logger: app.logger,
                                      mode: .limit(1))

            // validate versions
            let p = try await Package.find(pkgId, on: app.db).unwrap()
            try await p.$versions.load(on: app.db)
            let versions = p.versions.map(\.reference.description).sorted()
            XCTAssertEqual(versions, ["1.0.0", "main"])
        }

        do {  // third scenario: everything throws
            Current.shell.run = { _, _ in throw Error() }
            Current.git.getTags = { _ in throw Error() }
            Current.git.revisionInfo = { _, _ in throw Error() }

            // MUT
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      logger: app.logger,
                                      mode: .limit(1))

            // validate versions
            let p = try await Package.find(pkgId, on: app.db).unwrap()
            try await p.$versions.load(on: app.db)
            let versions = p.versions.map(\.reference.description).sorted()
            XCTAssertEqual(versions, ["1.0.0", "main"])
        }
    }

    func test_issue_2571_latest_version() async throws {
        // Ensure `latest` remains set in case of AppError.noValidVersions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2571
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1".asGithubUrl.url, processingStage: .ingestion)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             name: "1",
                             owner: "foo").save(on: app.db)
        try await Version(package: pkg,
                          commit: "commit0",
                          commitDate: .t0,
                          latest: .defaultBranch,
                          packageName: "foo-1",
                          reference: .branch("main")).save(on: app.db)
        try await Version(package: pkg,
                          commit: "commit0",
                          commitDate: .t0,
                          latest: .release,
                          packageName: "foo-1",
                          reference: .tag(1, 0, 0)).save(on: app.db)
        Current.fileManager.fileExists = { _ in true }
        Current.git.commitCount = { _ in 2 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.hasBranch = { _, _ in true }
        Current.git.lastCommitDate = { _ in .t1 }
        struct Error: Swift.Error { }
        Current.git.shortlog = { _ in
            """
            1\tPerson 1
            1\tPerson 2
            """
        }
        Current.git.getTags = { _ in [.tag(1, 0, 0)] }
        Current.shell.run = { cmd, path in return "" }

        do {  // ensure happy path passes test (no revision changes)
            Current.git.revisionInfo = { ref, _ in
                switch ref {
                    case .tag(.init(1, 0, 0), "1.0.0"):
                        return .init(commit: "commit0", date: .t0)
                    case .branch("main"):
                        return .init(commit: "commit0", date: .t0)
                    default:
                        throw Error()
                }
            }

            // MUT
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      logger: app.logger,
                                      mode: .limit(1))

            // validate versions
            let p = try await Package.find(pkgId, on: app.db).unwrap()
            try await p.$versions.load(on: app.db)
            let versions = p.versions.sorted(by: { $0.reference.description < $1.reference.description })
            XCTAssertEqual(versions.map(\.reference.description), ["1.0.0", "main"])
            XCTAssertEqual(versions.map(\.latest), [.release, .defaultBranch])
        }

        // make package available for analysis again
        pkg.processingStage = .ingestion
        try await pkg.save(on: app.db)

        do {  // simulate "main" branch moving forward to ("commit0", .t1)
            Current.git.revisionInfo = { ref, _ in
                switch ref {
                    case .tag(.init(1, 0, 0), "1.0.0"):
                        return .init(commit: "commit0", date: .t0)
                    case .branch("main"):
                        // main branch has new commit
                        return .init(commit: "commit1", date: .t1)
                    default:
                        throw Error()
                }
            }
            Current.shell.run = { cmd, path in
                // simulate error in getPackageInfo by failing checkout
                if cmd == .gitCheckout(branch: "main") {
                    throw Error()
                }
                return ""
            }

            // MUT
            try await Analyze.analyze(client: app.client,
                                      database: app.db,
                                      logger: app.logger,
                                      mode: .limit(1))

            // validate error logs
            try logger.logs.withValue { logs in
                XCTAssertEqual(logs.count, 1)
                let error = try logs.first.unwrap()
                XCTAssertTrue(error.message.contains("AppError.noValidVersions"), "was: \(error.message)")
            }
            // validate versions
            let p = try await Package.find(pkgId, on: app.db).unwrap()
            try await p.$versions.load(on: app.db)
            let versions = p.versions.sorted(by: { $0.reference.description < $1.reference.description })
            XCTAssertEqual(versions.map(\.reference.description), ["1.0.0", "main"])
            XCTAssertEqual(versions.map(\.latest), [.release, .defaultBranch])
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
}
