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

import DependencyResolution
import Fluent
import ShellOut
import SnapshotTesting
import Vapor
import XCTest


class AnalyzerTests: AppTestCase {
    
    func test_analyze() throws {
        // End-to-end test, where we mock at the shell command level (i.e. we
        // don't mock the git commands themselves to ensure we're running the
        // expected shell commands for the happy path.)
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        let pkgs = try savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
        try Repository(package: pkgs[0],
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       releases: [
                        .mock(description: "rel 1.0.0", tagName: "1.0.0")
                       ],
                       stars: 25).save(on: app.db).wait()
        try Repository(package: pkgs[1],
                       defaultBranch: "main",
                       name: "2",
                       owner: "foo",
                       stars: 100).save(on: app.db).wait()
        var checkoutDir: String? = nil
        Current.fileManager.fileExists = { path in
            // let the check for the second repo checkout path succeed to simulate pull
            if let outDir = checkoutDir, path == "\(outDir)/github.com-foo-2" { return true }
            if path.hasSuffix("Package.swift") { return true }
            if path.hasSuffix("Package.resolved") { return true }
            return false
        }
        Current.fileManager.contents = { path in
            if path.hasSuffix("github.com-foo-1/Package.resolved") {
                return .mockPackageResolved(for: "foo-1")
            } else {
                return nil
            }
        }
        Current.fileManager.createDirectory = { path, _, _ in checkoutDir = path }
        Current.git = .live
        var commands = [Command]()
        Current.shell.run = { cmd, path in
            try self.testQueue.sync {
                let trimmedPath = path.replacingOccurrences(of: checkoutDir!,
                                                            with: ".")
                commands.append(try XCTUnwrap(.init(command: cmd, path: trimmedPath)))
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
                      "targets": [{"name": "t1"}]
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
                      "targets": [{"name": "t2"}]
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
            
            return ""
        }
        
        // MUT
        try Analyze.analyze(client: app.client,
                            database: app.db,
                            logger: app.logger,
                            threadPool: app.threadPool,
                            mode: .limit(10)).wait()
        
        // validation
        let outDir = try XCTUnwrap(checkoutDir)
        XCTAssert(outDir.hasSuffix("SPI-checkouts"), "unexpected checkout dir, was: \(outDir)")
        XCTAssertEqual(commands.count, 32)

        // Snapshot for each package individually to avoid ordering issues when
        // concurrent processing causes commands to interleave between packages.
        assertSnapshot(matching: commands
                        .filter { $0.path.hasSuffix("foo-1") }
                        .map(\.description), as: .dump)
        assertSnapshot(matching: commands
                        .filter { $0.path.hasSuffix("foo-2") }
                        .map(\.description), as: .dump)

        // validate versions
        // A bit awkward... create a helper? There has to be a better way?
        let pkg1 = try Package.query(on: app.db).filter(by: urls[0].url).with(\.$versions).first().wait()!
        XCTAssertEqual(pkg1.status, .ok)
        XCTAssertEqual(pkg1.processingStage, .analysis)
        XCTAssertEqual(pkg1.versions.map(\.packageName), ["foo-1", "foo-1", "foo-1"])
        let sortedVersions1 = pkg1.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
        XCTAssertEqual(sortedVersions1.map(\.reference.description), ["main", "1.0.0", "1.1.1"])
        XCTAssertEqual(sortedVersions1.map(\.latest), [.defaultBranch, nil, .release])
        XCTAssertEqual(sortedVersions1.map(\.releaseNotes), [nil, "rel 1.0.0", nil])
        XCTAssertEqual(sortedVersions1
                        .flatMap { $0.resolvedDependencies ?? [] }
                        .map(\.packageName),
                       ["foo-1", "foo-1", "foo-1"])

        let pkg2 = try Package.query(on: app.db).filter(by: urls[1].url).with(\.$versions).first().wait()!
        XCTAssertEqual(pkg2.status, .ok)
        XCTAssertEqual(pkg2.processingStage, .analysis)
        XCTAssertEqual(pkg2.versions.map(\.packageName), ["foo-2", "foo-2", "foo-2"])
        let sortedVersions2 = pkg2.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
        XCTAssertEqual(sortedVersions2.map(\.reference.description), ["main", "2.0.0", "2.1.0"])
        XCTAssertEqual(sortedVersions2.map(\.latest), [.defaultBranch, nil, .release])
        XCTAssertEqual(sortedVersions2
                        .flatMap { $0.resolvedDependencies ?? [] }
                        .map(\.packageName),
                       [])

        // validate products
        // (2 packages with 3 versions with 1 product each = 6 products)
        let products = try Product.query(on: app.db).sort(\.$name).all().wait()
        XCTAssertEqual(products.count, 6)
        assertEquals(products, \.name, ["p1", "p1", "p1", "p2", "p2", "p2"])
        assertEquals(products, \.targets,
                     [["t1"], ["t1"], ["t1"], ["t2"], ["t2"], ["t2"]])
        assertEquals(products, \.type, [.executable, .executable, .executable, .library(.automatic), .library(.automatic), .library(.automatic)])

        // validate targets
        // (2 packages with 3 versions with 1 target each = 6 targets)
        let targets = try Target.query(on: app.db).sort(\.$name).all().wait()
        XCTAssertEqual(targets.map(\.name), ["t1", "t1", "t1", "t2", "t2", "t2"])
        
        // validate score
        XCTAssertEqual(pkg1.score, 35)
        XCTAssertEqual(pkg2.score, 45)
        
        // ensure stats, recent packages, and releases are refreshed
        XCTAssertEqual(try Stats.fetch(on: app.db).wait(), .init(packageCount: 2))
        XCTAssertEqual(try RecentPackage.fetch(on: app.db).wait().count, 2)
        XCTAssertEqual(try RecentRelease.fetch(on: app.db).wait().count, 2)
    }

    func test_analyze_version_update() throws {
        // Ensure that new incoming versions update the latest properties and
        // move versions in case commits change. Tests both default branch commits
        // changing as well as a tag being moved to a different commit.
        // setup
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1".asGithubUrl.url, processingStage: .ingestion)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg,
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo").save(on: app.db).wait()
        // add existing versions (to be reconciled)
        try Version(package: pkg,
                    commit: "commit0",
                    commitDate: .t0,
                    latest: .defaultBranch,
                    packageName: "foo-1",
                    reference: .branch("main")).save(on: app.db).wait()
        try Version(package: pkg,
                    commit: "commit0",
                    commitDate: .t0,
                    latest: .release,
                    packageName: "foo-1",
                    reference: .tag(1, 0, 0)).save(on: app.db).wait()

        Current.fileManager.fileExists = { _ in true }

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t2 }
        Current.git.getTags = { _ in [.tag(1, 0, 0), .tag(1, 1, 1)] }
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

        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("package dump-package") {
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
        try Analyze.analyze(client: app.client,
                            database: app.db,
                            logger: app.logger,
                            threadPool: app.threadPool,
                            mode: .limit(10)).wait()

        // validate versions
        let p = try XCTUnwrap(Package.find(pkgId, on: app.db).wait())
        try p.$versions.load(on: app.db).wait()
        let versions = p.versions.sorted(by: { $0.commitDate < $1.commitDate })
        XCTAssertEqual(versions.map(\.commitDate), [.t1, .t2, .t3])
        XCTAssertEqual(versions.map(\.reference.description), ["1.0.0", "1.1.1", "main"])
        XCTAssertEqual(versions.map(\.latest), [nil, .release, .defaultBranch])
        XCTAssertEqual(versions.map(\.commit), ["commit1", "commit2", "commit3"])
    }

    func test_package_status() throws {
        // Ensure packages record success/error status
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        let pkgs = try savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
        try pkgs.forEach {
            try Repository(package: $0, defaultBranch: "main").save(on: app.db).wait()
        }
        let lastUpdate = Date()

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.getTags = { _ in [.tag(1, 0, 0)] }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }

        Current.shell.run = { cmd, path in
            // first package fails
            if cmd.string.hasSuffix("swift package dump-package") && path.hasSuffix("foo-1") {
                return "bad data"
            }
            // second package succeeds
            if cmd.string.hasSuffix("swift package dump-package") && path.hasSuffix("foo-2") {
                return #"{ "name": "SPI-Server", "products": [], "targets": [] }"#
            }
            return ""
        }
        
        // MUT
        try Analyze.analyze(client: app.client,
                            database: app.db,
                            logger: app.logger,
                            threadPool: app.threadPool,
                            mode: .limit(10)).wait()
        
        // assert packages have been updated
        let packages = try Package.query(on: app.db).sort(\.$createdAt).all().wait()
        packages.forEach { XCTAssert($0.updatedAt! > lastUpdate) }
        XCTAssertEqual(packages.map(\.status), [.noValidVersions, .ok])
    }
    
    func test_continue_on_exception() throws {
        // Test to ensure exceptions don't break processing
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        let pkgs = try savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
        try pkgs.forEach {
            try Repository(package: $0, defaultBranch: "main").save(on: app.db).wait()
        }
        var checkoutDir: String? = nil

        Current.fileManager.fileExists = { path in
            // let the check for the second repo checkout path succedd to simulate pull
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
        ]
        for (idx, ref) in refs.enumerated() {
            mockResults[.gitRevisionInfo(reference: ref)] = "sha-\(idx)"
        }

        var commands = [Command]()
        Current.shell.run = { cmd, path in
            try self.testQueue.sync {
                commands.append(try XCTUnwrap(.init(command: cmd, path: path)))
            }

            if let result = mockResults[cmd] { return result }

            // returning a blank string will cause an exception when trying to
            // decode it as the manifest result - we use this to simulate errors
            return ""
        }
        
        // MUT
        try Analyze.analyze(client: app.client,
                            database: app.db,
                            logger: app.logger,
                            threadPool: app.threadPool,
                            mode: .limit(10)).wait()
        
        // validation (not in detail, this is just to ensure command count is as expected)
        // Test setup is identical to `test_basic_analysis` except for the Manifest JSON,
        // which we intentionally broke. Command count must remain the same.
        XCTAssertEqual(commands.count, 32, "was: \(dump(commands))")
        // 2 packages with 2 tags + 1 default branch each -> 6 versions
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 6)
    }
    
    func test_refreshCheckout() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".asGithubUrl.url)
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        Current.fileManager.fileExists = { _ in true }
        var commands = [String]()
        Current.shell.run = { cmd, path in
            self.testQueue.sync {
                // mask variable checkout
                let checkoutDir = Current.fileManager.checkoutsDirectory()
                commands.append(cmd.string.replacingOccurrences(of: checkoutDir, with: "..."))
            }
            return ""
        }
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        
        // MUT
        _ = try Analyze.refreshCheckout(eventLoop: app.eventLoopGroup.next(),
                                        logger: app.logger,
                                        threadPool: app.threadPool,
                                        package: jpr).wait()
        
        // validate
        assertSnapshot(matching: commands, as: .dump)
    }
    
    func test_refreshCheckout_continueOnError() throws {
        // Test that processing continues on if a url in invalid
        // setup - first URL is not a valid url
        try savePackages(on: app.db, ["1", "2".asGithubUrl].asURLs, processingStage: .ingestion)
        let pkgs = Package.fetchCandidates(app.db, for: .analysis, limit: 10)
        
        // MUT
        let res = try pkgs.flatMap {
            Analyze.refreshCheckouts(eventLoop: self.app.eventLoopGroup.next(),
                                     logger: self.app.logger,
                                     threadPool: self.app.threadPool,
                                     packages: $0)
        }.wait()
        
        // validation
        XCTAssertEqual(res.count, 2)
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
    }
    
    func test_updateRepository() throws {
        // setup
        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.shell.run = { cmd, _ in throw TestError.unknownCommand }
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(id: .id1, package: pkg, defaultBranch: "main").save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: .id0).wait()

        // MUT
        try Analyze.updateRepository(on: app.db, package: jpr).wait()
        
        // validate
        let repo = try Repository.find(.id1, on: app.db).wait()
        XCTAssertEqual(repo?.commitCount, 12)
        XCTAssertEqual(repo?.firstCommitDate, .t0)
        XCTAssertEqual(repo?.lastCommitDate, .t1)
    }
    
    func test_updateRepositories() throws {
        // setup
        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.shell.run = { cmd, _ in throw TestError.unknownCommand }
        let pkg = Package(id: UUID(), url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        let packages: [Result<Joined<Package, Repository>, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.invalidPackageUrl(nil, "some reason")),
            .success(jpr)
        ]
        
        // MUT
        let results: [Result<Joined<Package, Repository>, Error>] =
        try Analyze.updateRepositories(on: app.db, packages: packages).wait()
        
        // validate
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map(\.isSuccess), [false, true])
        // ensure results are persisted
        let repo = try XCTUnwrap(Repository.query(on: app.db)
                                    .filter(\.$package.$id == pkg.id!)
                                    .first()
                                    .wait())
        XCTAssertEqual(repo.commitCount, 12)
        XCTAssertEqual(repo.firstCommitDate, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(repo.lastCommitDate, Date(timeIntervalSince1970: 1))
    }

    func test_diffVersions() throws {
        //setup
        Current.git.getTags = { _ in [.tag(1, 2, 3)] }
        Current.git.revisionInfo = { ref, _ in
            if ref == .branch("main") { return . init(commit: "sha.main", date: .t0) }
            if ref == .tag(1, 2, 3) { return .init(commit: "sha.1.2.3", date: .t1) }
            fatalError("unknown ref: \(ref)")
        }
        Current.shell.run = { cmd, _ in throw TestError.unknownCommand }
        let pkgId = UUID()
        do {
            let pkg = Package(id: pkgId, url: "1".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        }
        let pkg = try Package.fetchCandidate(app.db, id: pkgId).wait()

        // MUT
        let delta = try Analyze.diffVersions(client: app.client,
                                             logger: app.logger,
                                             threadPool: app.threadPool,
                                             transaction: app.db,
                                             package: pkg).wait()

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

    func test_diffVersions_package_list() throws {
        //setup
        Current.git.getTags = { _ in [.tag(1, 2, 3)] }
        Current.git.revisionInfo = { ref, _ in .init(commit: "sha", date: .t0) }
        Current.shell.run = { cmd, _ in throw TestError.unknownCommand }
        let pkgId = UUID()
        do {
            let pkg = Package(id: pkgId, url: "1".asGithubUrl.url)
            try pkg.save(on: app.db).wait()
            try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        }
        let pkg = try Package.fetchCandidate(app.db, id: pkgId).wait()
        let packages: [Result<Joined<Package, Repository>, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.invalidPackageUrl(nil, "some reason")),
            .success(pkg)
        ]

        // MUT
        let results = try Analyze.diffVersions(client: app.client,
                                               logger: app.logger,
                                               threadPool: app.threadPool,
                                               transaction: app.db,
                                               packages: packages).wait()

        // validate
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map(\.isSuccess), [false, true])
        let (_, delta) = try XCTUnwrap(results.last).get()
        assertEquals(delta.toAdd, \.reference.description, ["main", "1.2.3"])
        XCTAssertEqual(delta.toDelete, [])
    }

    func test_mergeReleaseInfo() throws {
        // setup
        let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, releases:[
            .mock(description: "rel 1.2.3", publishedAt: 1, tagName: "1.2.3"),
            .mock(description: "rel 2.0.0", publishedAt: 2, tagName: "2.0.0"),
            // 2.1.0 release note is missing on purpose
            .mock(description: "rel 2.2.0", isDraft: true, publishedAt: 3, tagName: "2.2.0"),
            .mock(description: "rel 2.3.0", publishedAt: 4, tagName: "2.3.0", url: "some url"),
            .mock(description: nil, tagName: "2.4.0")
        ]).save(on: app.db).wait()
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
        let jpr = try Package.fetchCandidate(app.db, id: .id0).wait()

        // MUT
        let res = try Analyze.mergeReleaseInfo(on: app.db,
                                               package: jpr,
                                               versions: versions)
            .wait()

        // validate
        let sortedResults = res.sorted { $0.commitDate < $1.commitDate }
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

    func test_getPackageInfo_package_version() throws {
        // Tests getPackageInfo(package:version:)
        // setup
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            self.testQueue.sync {
                commands.append(cmd.string)
            }
            if cmd == .swiftDumpPackage {
                return #"{ "name": "SPI-Server", "products": [], "targets": [] }"#
            }
            return ""
        }
        Current.fileManager.contents = { _ in
            Data.mockPackageResolved(for: "1")
        }
        let pkg = try savePackage(on: app.db, "https://github.com/foo/1")
        let version = try Version(id: UUID(), package: pkg, reference: .tag(.init(0, 4, 2)))
        try version.save(on: app.db).wait()

        // MUT
        let (analyzedVersion, info) = try Analyze.getPackageInfo(package: .init(model: pkg),
                                                                 version: version).get()
        
        // validation
        XCTAssertEqual(commands, [
            "git checkout \"0.4.2\" --quiet",
            "swift package dump-package"
        ])
        XCTAssertEqual(analyzedVersion.id, version.id)
        XCTAssertEqual(info.manifest.name, "SPI-Server")
        XCTAssertEqual(info.dependencies?.map(\.packageName), ["1"])
    }

    func test_getResolvedDependencies() throws {
        // setup
        Current.fileManager.contents = { _ in
            Data.mockPackageResolved(for: "Foo")
        }

        // MUT
        let deps = getResolvedDependencies(Current.fileManager, at: "path")

        // validate
        XCTAssertEqual(deps?.map(\.packageName), ["Foo"])
    }

    func test_getPackageInfo_packageAndVersionsl() throws {
        // Tests getPackageInfo(packageAndVersions:)
        // setup
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            self.testQueue.sync {
                commands.append(cmd.string)
            }
            if cmd == .swiftDumpPackage {
                return #"{ "name": "SPI-Server", "products": [], "targets": [] }"#
            }
            return ""
        }
        Current.fileManager.contents = { _ in
            Data.mockPackageResolved(for: "1")
        }
        let pkg = try savePackage(on: app.db, "https://github.com/foo/1")
        let version = try Version(id: UUID(), package: pkg, reference: .tag(.init(0, 4, 2)))
        try version.save(on: app.db).wait()
        
        let packageAndVersions: [Result<(Joined<Package, Repository>, [Version]), Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.invalidPackageUrl(nil, "some reason")),
            .success((.init(model: pkg), [version]))
        ]
        
        // MUT
        let results = Analyze.getPackageInfo(packageAndVersions: packageAndVersions)
        
        // validation
        XCTAssertEqual(commands, [
            "git checkout \"0.4.2\" --quiet",
            "swift package dump-package"
        ])
        XCTAssertEqual(results.map(\.isSuccess), [false, true])
        let (_, pkgInfo) = try XCTUnwrap(results.last).get()
        XCTAssertEqual(pkgInfo.count, 1)
        let (v, info) = try XCTUnwrap(pkgInfo.first)
        XCTAssertEqual(v, version)
        XCTAssertEqual(info.manifest.name, "SPI-Server")
        XCTAssertEqual(info.dependencies?.map(\.packageName), ["1"])
    }
    
    func test_updateVersion() throws {
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        let version = try Version(package: pkg)
        let manifest = Manifest(name: "foo",
                                platforms: [.init(platformName: .ios, version: "11.0"),
                                            .init(platformName: .macos, version: "10.10")],
                                products: [],
                                swiftLanguageVersions: ["1", "2", "3.0.0"],
                                targets: [],
                                toolsVersion: .init(version: "5.0.0"))
        let dep = ResolvedDependency(packageName: "foo",
                                     repositoryURL: "http://foo.com")

        // MUT
        _ = try Analyze.updateVersion(on: app.db,
                                      version: version,
                                      packageInfo: .init(manifest: manifest,
                                                         dependencies: [dep])).wait()

        // read back and validate
        let v = try Version.query(on: app.db).first().wait()!
        XCTAssertEqual(v.packageName, "foo")
        XCTAssertEqual(v.resolvedDependencies?.map(\.packageName),
                       ["foo"])
        XCTAssertEqual(v.swiftVersions, ["1", "2", "3.0.0"].asSwiftVersions)
        XCTAssertEqual(v.supportedPlatforms, [.ios("11.0"), .macos("10.10")])
        XCTAssertEqual(v.toolsVersion, "5.0.0")
    }

    func test_updateVersion_preserveDependencies() throws {
        // Ensure we don't overwrite existing dependencies when update value is nil
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        let version = try Version(
            package: pkg,
            resolvedDependencies: [ResolvedDependency(packageName: "foo",
                                                      repositoryURL: "")]
        )
        let manifest = Manifest(name: "foo",
                                platforms: [.init(platformName: .ios, version: "11.0"),
                                            .init(platformName: .macos, version: "10.10")],
                                products: [],
                                swiftLanguageVersions: [],
                                targets: [],
                                toolsVersion: .init(version: "5.0.0"))

        // MUT
        _ = try Analyze.updateVersion(on: app.db,
                                      version: version,
                                      packageInfo: .init(manifest: manifest,
                                                         dependencies: nil)).wait()

        // read back and validate
        let v = try Version.query(on: app.db).first().wait()!
        XCTAssertEqual(v.resolvedDependencies?.map(\.packageName),
                       ["foo"])
    }

    func test_updateVersion_reportUnknownPlatforms() throws {
        // Ensure we report encountering unhandled platforms
        // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/51
        
        // Asserting that the platform name cases agree is the only thing we need to do.
        // - Platform.version is a String on both sides
        // - Swift Versions map to SemVar and so there is no conceivable way at this time
        //   to write an incompatible Swift Version
        // The only possible issue could be adding a new platform to Manifest.Platform
        // and forgetting to add it to Platform (the model). This test will fail in
        // that case.
        XCTAssertEqual(Manifest.Platform.Name.allCases.map(\.rawValue).sorted(),
                       Platform.Name.allCases.map(\.rawValue).sorted())
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
                         targets: [.init(name: "t1"), .init(name: "t2")],
                         toolsVersion: .init(version: "5.0.0"))
        try p.save(on: app.db).wait()
        try v.save(on: app.db).wait()

        // MUT
        try Analyze.createTargets(on: app.db, version: v, manifest: m).wait()

        // validation
        let targets = try Target.query(on: app.db).sort(\.$createdAt).all().wait()
        XCTAssertEqual(targets.map(\.name), ["t1", "t2"])
    }

    func test_updatePackage() throws {
        // setup
        let packages = try savePackages(on: app.db, ["1", "2"].asURLs)
            .map(Joined<Package, Repository>.init(model:))
        let results: [Result<Joined<Package, Repository>, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.noValidVersions(try packages[0].model.requireID(), "1")),
            .success(packages[1])
        ]
        
        // MUT
        try updatePackages(client: app.client,
                           database: app.db,
                           logger: app.logger,
                           results: results,
                           stage: .analysis).wait()
        
        // validate
        do {
            let packages = try Package.query(on: app.db).sort(\.$url).all().wait()
            assertEquals(packages, \.status, [.noValidVersions, .ok])
            assertEquals(packages, \.processingStage, [.analysis, .analysis])
        }
    }
    
    func test_issue_29() throws {
        // Regression test for issue 29
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/29
        // setup
        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t1 }
        Current.git.getTags = { _ in [.tag(1, 0, 0), .tag(2, 0, 0)] }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }
        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
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
        try Analyze.analyze(client: app.client,
                            database: app.db,
                            logger: app.logger,
                            threadPool: app.threadPool,
                            mode: .limit(10)).wait()
        
        // validation
        // 1 version for the default branch + 2 for the tags each = 6 versions
        // 2 products per version = 12 products
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 6)
        XCTAssertEqual(try Product.query(on: app.db).count().wait(), 12)
    }
    
    func test_issue_70() throws {
        // Certain git commands fail when index.lock exists
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/70
        // setup
        try savePackage(on: app.db, "1".asGithubUrl.url, processingStage: .ingestion)
        let pkgs = Package.fetchCandidates(app.db, for: .analysis, limit: 10)
        
        let checkoutDir = Current.fileManager.checkoutsDirectory()
        // claim every file exists, including our ficticious 'index.lock' for which
        // we want to trigger the cleanup mechanism
        Current.fileManager.fileExists = { path in true }
        
        var commands = [String]()
        Current.shell.run = { cmd, path in
            self.testQueue.sync {
                let c = cmd.string.replacingOccurrences(of: checkoutDir, with: "...")
                commands.append(c)
            }
            return ""
        }
        
        // MUT
        let res = try pkgs.flatMap {
            Analyze.refreshCheckouts(eventLoop: self.app.eventLoopGroup.next(),
                                     logger: self.app.logger,
                                     threadPool: self.app.threadPool,
                                     packages: $0)
        }.wait()
        
        // validation
        XCTAssertEqual(res.map(\.isSuccess), [true])
        assertSnapshot(matching: commands, as: .dump)
    }

    func test_issue_498() throws {
        // git checkout can still fail despite git reset --hard + git clean
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/498
        // setup
        try savePackage(on: app.db, "1".asGithubUrl.url, processingStage: .ingestion)
        let pkgs = try Package.fetchCandidates(app.db, for: .analysis, limit: 10).wait()

        let checkoutDir = Current.fileManager.checkoutsDirectory()
        // claim every file exists, including our ficticious 'index.lock' for which
        // we want to trigger the cleanup mechanism
        Current.fileManager.fileExists = { path in true }

        var commands = [String]()
        Current.shell.run = { cmd, path in
            self.testQueue.sync {
                let c = cmd.string.replacingOccurrences(of: checkoutDir, with: "${checkouts}")
                commands.append(c)
            }
            if cmd == .gitCheckout(branch: "master") {
                throw TestError.simulatedCheckoutError
            }
            return ""
        }

        // MUT
        let res = try Analyze.refreshCheckouts(eventLoop: self.app.eventLoopGroup.next(),
                                               logger: self.app.logger,
                                               threadPool: self.app.threadPool,
                                               packages: pkgs).wait()

        // validation
        XCTAssertEqual(res.map(\.isSuccess), [true])
        assertSnapshot(matching: commands, as: .dump)
    }

    func test_dumpPackage_5_4() throws {
        // Test parsing a Package.swift that requires a 5.4 toolchain
        // NB: If this test fails on macOS with Xcode 12, make sure
        // xcode-select -p points to the correct version of Xcode!
        // setup
        Current.fileManager = .live
        Current.shell = .live
        try withTempDir { tempDir in
            let fixture = fixturesDirectory()
                .appendingPathComponent("VisualEffects-Package-swift").path
            let fname = tempDir.appending("/Package.swift")
            try ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
            let m = try Analyze.dumpPackage(at: tempDir)
            XCTAssertEqual(m.name, "VisualEffects")
        }
    }

    func test_dumpPackage_5_5() throws {
        // Test parsing a Package.swift that requires a 5.5 toolchain
        // NB: If this test fails on macOS with Xcode 12, make sure
        // xcode-select -p points to the correct version of Xcode!
        // See also https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1441
        // setup
        Current.fileManager = .live
        Current.shell = .live
        try withTempDir { tempDir in
            let fixture = fixturesDirectory()
                .appendingPathComponent("Firestarter-Package-swift").path
            let fname = tempDir.appending("/Package.swift")
            try ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
            let m = try Analyze.dumpPackage(at: tempDir)
            XCTAssertEqual(m.name, "Firestarter")
        }
    }

    func test_issue_577() throws {
        // Duplicate "latest release" versions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/577
        // setup
        let pkgId = UUID()
        let pkg = Package(id: pkgId, url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        // existing "latest release" version
        try Version(package: pkg, latest: .release, packageName: "foo", reference: .tag(1, 2, 3))
            .save(on: app.db).wait()
        // new, not yet considered release version
        try Version(package: pkg, packageName: "foo", reference: .tag(1, 3, 0))
            .save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()

        // MUT
        try Analyze.updateLatestVersions(on: app.db, package: jpr).wait()

        // validate
        do {  // refetch package to ensure changes are persisted
            let pkg = try XCTUnwrap(Package.find(pkgId, on: app.db).wait())
            try pkg.$versions.load(on: app.db).wait()
            let versions = pkg.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
            XCTAssertEqual(versions.map(\.reference.description), ["1.2.3", "1.3.0"])
            XCTAssertEqual(versions.map(\.latest), [nil, .release])
        }
    }

    func test_issue_693() throws {
        // Handle moved tags
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/693
        // setup
        do {
            let pkg = try savePackage(on: app.db, id: .id0, "1".asGithubUrl.url)
            try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        }
        let pkg = try Package.fetchCandidate(app.db, id: .id0).wait()
        Current.fileManager.fileExists = { _ in true }
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            self.testQueue.sync {
                // mask variable checkout
                let checkoutDir = Current.fileManager.checkoutsDirectory()
                commands.append(cmd.string.replacingOccurrences(of: checkoutDir, with: "..."))
            }
            if cmd == .gitFetch { throw TestError.simulatedFetchError }
            return ""
        }

        // MUT
        _ = try Analyze.refreshCheckout(eventLoop: app.eventLoopGroup.next(),
                                        logger: app.logger,
                                        threadPool: app.threadPool,
                                        package: pkg).wait()

        // validate
        assertSnapshot(matching: commands, as: .dump)
    }

    func test_updateLatestVersions() throws {
        // setup
        func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        try Version(package: pkg, commitDate: t(2), packageName: "foo", reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: pkg, commitDate: t(0), packageName: "foo", reference: .tag(1, 2, 3))
            .save(on: app.db).wait()
        try Version(package: pkg, commitDate: t(1), packageName: "foo", reference: .tag(2, 0, 0, "rc1"))
            .save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()

        // MUT
        try Analyze.updateLatestVersions(on: app.db, package: jpr).wait()

        // validate
        try pkg.$versions.load(on: app.db).wait()
        let versions = pkg.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
        XCTAssertEqual(versions.map(\.reference.description), ["main", "1.2.3", "2.0.0-rc1"])
        XCTAssertEqual(versions.map(\.latest), [.defaultBranch, .release, .preRelease])
    }

    func test_updateLatestVersions_old_beta() throws {
        // Test to ensure outdated betas aren't picked up as latest versions
        // and that faulty db content (outdated beta marked as latest pre-release)
        // is correctly reset.
        // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/188
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "main").save(on: app.db).wait()
        try Version(package: pkg,
                    latest: .defaultBranch,
                    packageName: "foo",
                    reference: .branch("main"))
            .save(on: app.db).wait()
        try Version(package: pkg,
                    latest: .release,
                    packageName: "foo",
                    reference: .tag(2, 0, 0))
            .save(on: app.db).wait()
        try Version(package: pkg,
                    latest: .preRelease,  // this should have been nil - ensure it's reset
                    packageName: "foo",
                    reference: .tag(2, 0, 0, "rc1"))
            .save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()

        // MUT
        try Analyze.updateLatestVersions(on: app.db, package: jpr).wait()

        // validate
        let versions = try Version.query(on: app.db)
            .sort(\.$createdAt).all().wait()
        XCTAssertEqual(versions.map(\.reference.description), ["main", "2.0.0", "2.0.0-rc1"])
        XCTAssertEqual(versions.map(\.latest), [.defaultBranch, .release, nil])
    }

    func test_onNewVersions() throws {
        // ensure that onNewVersions does not propagate errors
        // setup
        Current.twitterPostTweet = { _, _ in
            // simulate failure (this is for good measure - our version will also raise an
            // invalidMessage error, because it is missing a repository)
            self.app.eventLoopGroup.future(error: Twitter.Error.missingCredentials)
        }
        let pkg = Package(url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try version.save(on: app.db).wait()
        let jpr = try Package.fetchCandidate(app.db, id: pkg.id!).wait()
        let packageResults: [Result<(Joined<Package, Repository>, [(Version, Manifest)]), Error>] = [
            .success((jpr, [(version, .mock)]))
        ]

        // MUT & validation (no error thrown)
        _ = try Analyze.onNewVersions(client: app.client,
                                      logger: app.logger,
                                      transaction: app.db,
                                      packageResults: packageResults).wait()
    }

    func test_issue_914() throws {
        // Ensure we handle 404 repos properly
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/914
        // setup
        do {
            let url = "1".asGithubUrl.url
            let pkg = Package.init(url: url, processingStage: .ingestion)
            try pkg.save(on: app.db).wait()
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
        try Analyze.analyze(client: app.client,
                            database: app.db,
                            logger: app.logger,
                            threadPool: app.threadPool,
                            mode: .limit(10)).wait()

        // validate
        let pkg = try XCTUnwrap(Package.query(on: app.db).first().wait())
        XCTAssertTrue(pkg.updatedAt! > lastUpdated)
        XCTAssertEqual(pkg.status, .analysisFailed)
    }

    func test_trimCheckouts() throws {
        // setup
        Current.fileManager.checkoutsDirectory = { "/checkouts" }
        Current.fileManager.contentsOfDirectory = { _ in ["foo", "bar"] }
        Current.fileManager.attributesOfItem = { path in
            [
                "/checkouts/foo": [FileAttributeKey.modificationDate: daysAgo(31)],
                "/checkouts/bar": [FileAttributeKey.modificationDate: daysAgo(29)],
            ][path]!
        }
        var removedPaths = [String]()
        Current.fileManager.removeItem = { removedPaths.append($0) }

        // MUT
        try Analyze.trimCheckouts()

        // validate
        XCTAssertEqual(removedPaths, ["/checkouts/foo"])
    }

}


// We shouldn't be conforming a type we don't own to protocols we don't own
// but in a test module we can loosen that rule a bit.
extension ShellOutCommand: Equatable, Hashable {
    public static func == (lhs: ShellOutCommand, rhs: ShellOutCommand) -> Bool {
        lhs.string == rhs.string
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(string)
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
        case reset
        case resetToBranch(String)
        case showDate
        case revisionInfo(String)
    }

    init?(command: ShellOutCommand, path: String) {
        let quotes = CharacterSet(charactersIn: "\"")
        let separator = "-"
        self.path = path
        switch command {
            case _ where command.string.starts(with: "git checkout"):
                let ref = String(command.string.split(separator: " ")[2])
                    .trimmingCharacters(in: quotes)
                self.kind = .checkout(ref)
            case .gitClean:
                self.kind = .clean
            case _ where command.string.starts(with: "git clone"):
                let url = String(command.string.split(separator: " ")
                                    .filter { $0.contains("https://") }
                                    .first!)
                self.kind = .clone(url)
            case .gitCommitCount:
                self.kind = .commitCount
            case .gitFetch:
                self.kind = .fetch
            case .gitFirstCommitDate:
                self.kind = .firstCommitDate
            case .gitLastCommitDate:
                self.kind = .lastCommitDate
            case .gitListTags:
                self.kind = .getTags
            case .gitReset(hard: true):
                self.kind = .reset
            case _ where command.string.starts(with: #"git reset "origin"#):
                let branch = String(command.string.split(separator: " ")[2])
                    .trimmingCharacters(in: quotes)
                self.kind = .resetToBranch(branch)
            case _ where command.string.starts(with: #"git show -s --format=%ct"#):
                self.kind = .showDate
            case _ where command.string.starts(with: #"git log -n1 --format=format:"%H\#(separator)%ct""#):
                let ref = String(command.string.split(separator: " ").last!)
                    .trimmingCharacters(in: quotes)
                self.kind = .revisionInfo(ref)
            case .swiftDumpPackage:
                self.kind = .dumpPackage
            default:
                return nil
        }
    }

    var description: String {
        switch self.kind {
            case .clean, .commitCount, .dumpPackage, .fetch, .firstCommitDate, .lastCommitDate, .getTags, .showDate, .reset:
                return "\(path): \(kind)"
            case .checkout(let ref):
                return "\(path): checkout \(ref)"
            case .clone(let url):
                return "\(path): clone \(url)"
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


private extension Data {
    static func mockPackageResolved(for packageName: String) -> Self {
        .init(
            #"""
            {
              "object": {
                "pins": [
                  {
                    "package": "\#(packageName)",
                    "repositoryURL": "https://github.com/foo/\#(packageName)",
                    "state": {
                      "branch": null,
                      "revision": "fca5fe8e7b8218d563f99daadffd86dbf11dd98b",
                      "version": "1.2.3"
                    }
                  }
                ],
                "version": 1
              }
            }
            """#.utf8
        )
    }
}
