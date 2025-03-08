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
import NIOConcurrencyHelpers
import SPIManifest
import SnapshotTesting
import Testing
import Vapor


@preconcurrency import ShellOut


extension AllTests.AnalyzerTests {

    @Test func analyze() async throws {
        // End-to-end test, where we mock at the shell command level (i.e. we
        // don't mock the git commands themselves to ensure we're running the
        // expected shell commands for the happy path.)
        try await withApp { app in
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
                #expect(outDir.hasSuffix("SPI-checkouts"), "unexpected checkout dir, was: \(outDir)")
                #expect(commands.value.count == 36)

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
                #expect(pkg1.status == .ok)
                #expect(pkg1.processingStage == .analysis)
                #expect(pkg1.versions.map(\.packageName) == ["foo-1", "foo-1", "foo-1"])
                let sortedVersions1 = pkg1.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
                #expect(sortedVersions1.map(\.reference.description) == ["main", "1.0.0", "1.1.1"])
                #expect(sortedVersions1.map(\.latest) == [.defaultBranch, nil, .release])
                #expect(sortedVersions1.map(\.releaseNotes) == [nil, "rel 1.0.0", nil])

                let pkg2 = try await Package.query(on: app.db).filter(by: urls[1].url).with(\.$versions).first()!
                #expect(pkg2.status == .ok)
                #expect(pkg2.processingStage == .analysis)
                #expect(pkg2.versions.map(\.packageName) == ["foo-2", "foo-2", "foo-2"])
                let sortedVersions2 = pkg2.versions.sorted(by: { $0.createdAt! < $1.createdAt! })
                #expect(sortedVersions2.map(\.reference.description) == ["main", "2.0.0", "2.1.0"])
                #expect(sortedVersions2.map(\.latest) == [.defaultBranch, nil, .release])

                // validate products
                // (2 packages with 3 versions with 1 product each = 6 products)
                let products = try await Product.query(on: app.db).sort(\.$name).all()
                #expect(products.count == 6)
                assertEquals(products, \.name, ["p1", "p1", "p1", "p2", "p2", "p2"])
                assertEquals(products, \.targets,
                             [["t1"], ["t1"], ["t1"], ["t2"], ["t2"], ["t2"]])
                assertEquals(products, \.type, [.executable, .executable, .executable, .library(.automatic), .library(.automatic), .library(.automatic)])

                // validate targets
                // (2 packages with 3 versions with 1 target each = 6 targets)
                let targets = try await Target.query(on: app.db).sort(\.$name).all()
                #expect(targets.map(\.name) == ["t1", "t1", "t1", "t2", "t2", "t2"])

                // validate score
                #expect(pkg1.score == 30)
                #expect(pkg2.score == 40)

                // ensure stats, recent packages, and releases are refreshed
                #expect(try await Stats.fetch(on: app.db) == .init(packageCount: 2))
                #expect(try await RecentPackage.fetch(on: app.db).count == 2)
                #expect(try await RecentRelease.fetch(on: app.db).count == 2)
            }
        }
    }

    @Test func analyze_version_update() async throws {
        // Ensure that new incoming versions update the latest properties and
        // move versions in case commits change. Tests both default branch commits
        // changing as well as a tag being moved to a different commit.
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .now
                $0.environment.allowSocialPosts = { true }
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 12 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.getTags = { @Sendable _ in [.tag(1, 0, 0), .tag(1, 1, 1)] }
                $0.git.hasBranch = { @Sendable _, _ in true }
                $0.git.lastCommitDate = { @Sendable _ in .t2 }
                $0.git.revisionInfo = { @Sendable ref, _ in
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
                $0.git.shortlog = { @Sendable _ in
                """
                10\tPerson 1
                 2\tPerson 2
                """
                }
                $0.httpClient.mastodonPost = { @Sendable _ in }
                $0.shell.run = { @Sendable cmd, path in
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
            } operation: {
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

                // MUT
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))

                // validate versions
                let p = try await Package.find(pkgId, on: app.db).unwrap()
                try await p.$versions.load(on: app.db)
                let versions = p.versions.sorted(by: { $0.commitDate < $1.commitDate })
                #expect(versions.map(\.commitDate) == [.t1, .t2, .t3])
                #expect(versions.map(\.reference.description) == ["1.0.0", "1.1.1", "main"])
                #expect(versions.map(\.latest) == [nil, .release, .defaultBranch])
                #expect(versions.map(\.commit) == ["commit1", "commit2", "commit3"])
            }
        }
    }

    @Test func forward_progress_on_analysisError() async throws {
        // Ensure a package that fails analysis goes back to ingesting and isn't stuck in an analysis loop
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .now
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 12 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.hasBranch = { @Sendable _, _ in false }  // simulate analysis error via branch mismatch
                $0.git.lastCommitDate = { @Sendable _ in .t1 }
                $0.git.shortlog = { @Sendable _ in "" }
                $0.shell.run = { @Sendable _, _ in "" }
            } operation: {
                // setup
                do {
                    let pkg = try await savePackage(on: app.db, "https://github.com/foo/1", processingStage: .ingestion)
                    try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
                }

                // Ensure candidate selection is as expected
                #expect(try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10).count == 0)
                #expect(try await Package.fetchCandidates(app.db, for: .analysis, limit: 10).count == 1)

                // MUT
                try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(10))

                // Ensure candidate selection is now zero for analysis
                // (and also for ingestion, as we're immediately after analysis)
                #expect(try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10).count == 0)
                #expect(try await Package.fetchCandidates(app.db, for: .analysis, limit: 10).count == 0)

                try await withDependencies {
                    // Advance time beyond reIngestionDeadtime
                    $0.date.now = .now.addingTimeInterval(Constants.reIngestionDeadtime)
                } operation: {
                    // Ensure candidate selection has flipped to ingestion
                    let ingestionCandidates = try await Package.fetchCandidates(app.db, for: .ingestion, limit: 10)
                    #expect(ingestionCandidates.count == 1)
                    let analysisCandidates = try await Package.fetchCandidates(app.db, for: .analysis, limit: 10)
                    #expect(analysisCandidates.count == 0)
                }
            }
        }
    }

    @Test func package_status() async throws {
        // Ensure packages record success/error status
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .now
                $0.environment.allowSocialPosts = { true }
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 12 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.getTags = { @Sendable _ in [.tag(1, 0, 0)] }
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
            } operation: {
                // setup
                let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
                let pkgs = try await savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
                for p in pkgs {
                    try await Repository(package: p, defaultBranch: "main").save(on: app.db)
                }
                let lastUpdate = Date()

                // MUT
                try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(10))

                // assert packages have been updated
                let packages = try await Package.query(on: app.db).sort(\.$createdAt).all()
                packages.forEach { #expect($0.updatedAt! > lastUpdate)  }
                #expect(packages.map(\.status) == [.noValidVersions, .ok])
            }
        }
    }

    @Test func continue_on_exception() async throws {
        // Test to ensure exceptions don't interrupt processing
        try await withApp { app in
            let checkoutDir: NIOLockedValueBox<String?> = .init(nil)
            let commands = QueueIsolated<[Command]>([])
            let refs: [Reference] = [.tag(1, 0, 0), .tag(1, 1, 1), .branch("main")]
            let mockResults = {
                var res: [ShellOutCommand: String] = [
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
                    res[.gitRevisionInfo(reference: ref)] = "sha-\(idx)"
                }
                return res
            }()
            try await withDependencies {
                $0.date.now = .now
                $0.environment.allowSocialPosts = { true }
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.createDirectory = { @Sendable path, _, _ in checkoutDir.withLockedValue { $0 = path } }
                $0.fileManager.fileExists = { @Sendable path in
                    if let outDir = checkoutDir.withLockedValue({ $0 }), path == "\(outDir)/github.com-foo-1" { return true }
                    if let outDir = checkoutDir.withLockedValue({ $0 }), path == "\(outDir)/github.com-foo-2" { return true }
                    if path.hasSuffix("Package.swift") { return true }
                    return false
                }
                $0.git = .liveValue
                $0.shell.run = { @Sendable cmd, path in
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
            } operation: {
                // setup
                let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
                let pkgs = try await savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
                for p in pkgs {
                    try await Repository(package: p, defaultBranch: "main").save(on: app.db)
                }

                // MUT
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))

                // validation (not in detail, this is just to ensure command count is as expected)
                #expect(commands.value.count == 40, "was: \(dump(commands.value))")
                // 1 packages with 2 tags + 1 default branch each -> 3 versions (the other package fails)
                let versionCount = try await Version.query(on: app.db).count()
                #expect(versionCount == 3)
            }
        }
    }

    @Test func refreshCheckout() async throws {
        try await withApp { app in
            let commands = QueueIsolated<[String]>([])
            try await withDependencies {
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.shell.run = { @Sendable cmd, path in
                    commands.withValue { $0.append(cmd.description) }
                    return ""
                }
            } operation: {
                // setup
                let pkg = try await savePackage(on: app.db, "1".asGithubUrl.url)
                try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
                let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

                // MUT
                _ = try await Analyze.refreshCheckout(package: jpr)

                // validate
                assertSnapshot(of: commands.value, as: .dump)
            }
        }
    }

    @Test func updateRepository() async throws {
        try await withApp { app in
            try await withDependencies {
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 12 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.lastCommitDate = { @Sendable _ in .t1 }
                $0.git.shortlog = { @Sendable _ in
                """
                10\tPerson 1
                 2\tPerson 2
                """
                }
                $0.shell.run = { @Sendable cmd, _ in throw TestError.unknownCommand }
            } operation: {
                // setup
                let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
                try await pkg.save(on: app.db)
                try await Repository(id: .id1, package: pkg, defaultBranch: "main").save(on: app.db)
                let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

                // MUT
                try await Analyze.updateRepository(on: app.db, package: jpr)

                // validate
                do { // ensure JPR relation is updated
                    #expect(jpr.repository?.commitCount == 12)
                    #expect(jpr.repository?.firstCommitDate == .t0)
                    #expect(jpr.repository?.lastCommitDate == .t1)
                    #expect(jpr.repository?.authors == PackageAuthors(authors: [Author(name: "Person 1")],
                                                                      numberOfContributors: 1))
                }
                do { // ensure changes are persisted
                    let repo = try await Repository.find(.id1, on: app.db)
                    #expect(repo?.commitCount == 12)
                    #expect(repo?.firstCommitDate == .t0)
                    #expect(repo?.lastCommitDate == .t1)
                    #expect(repo?.authors == PackageAuthors(authors: [Author(name: "Person 1")], numberOfContributors: 1))
                }
            }
        }
    }

    @Test func getIncomingVersions() async throws {
        try await withApp { app in
            try await withDependencies {
                $0.git.getTags = { @Sendable _ in [.tag(1, 2, 3)] }
                $0.git.hasBranch = { @Sendable _, _ in true }
                $0.git.revisionInfo = { @Sendable ref, _ in .init(commit: "sha-\(ref)", date: .t0) }
            } operation: {
                // setup
                do {
                    let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
                    try await pkg.save(on: app.db)
                    try await Repository(id: .id1, package: pkg, defaultBranch: "main").save(on: app.db)
                }
                let pkg = try await Package.fetchCandidate(app.db, id: .id0)

                // MUT
                let versions = try await Analyze.getIncomingVersions(client: app.client, package: pkg)

                // validate
                #expect(versions.map(\.commit).sorted() == ["sha-1.2.3", "sha-main"])
            }
        }
    }

    @Test func getIncomingVersions_default_branch_mismatch() async throws {
        try await withApp { app in
            try await withDependencies {
                $0.git.hasBranch = { @Sendable _, _ in false}  // simulate branch mismatch
            } operation: {
                // setup
                do {
                    let pkg = Package(id: .id0, url: "1".asGithubUrl.url)
                    try await pkg.save(on: app.db)
                    try await Repository(id: .id1, package: pkg, defaultBranch: "main").save(on: app.db)
                }
                let pkg = try await Package.fetchCandidate(app.db, id: .id0)

                // MUT
                do {
                    _ = try await Analyze.getIncomingVersions(client: app.client, package: pkg)
                    Issue.record("expected an analysisError to be thrown")
                } catch let AppError.analysisError(.some(pkgId), msg) {
                    // validate
                    #expect(pkgId == .id0)
                    #expect(msg == "Default branch 'main' does not exist in checkout")
                }
            }
        }
    }

    @Test func getIncomingVersions_no_default_branch() async throws {
        try await withApp { app in
            // setup
            // saving Package without Repository means it has no default branch
            try await Package(id: .id0, url: "1".asGithubUrl.url).save(on: app.db)
            let pkg = try await Package.fetchCandidate(app.db, id: .id0)

            // MUT
            do {
                _ = try await Analyze.getIncomingVersions(client: app.client, package: pkg)
                Issue.record("expected an analysisError to be thrown")
            } catch let AppError.analysisError(.some(pkgId), msg) {
                // validate
                #expect(pkgId == .id0)
                #expect(msg == "Package must have default branch")
            }
        }
    }

    @Test func diffVersions() async throws {
        try await withApp { app in
            try await withDependencies {
                $0.git.getTags = { @Sendable _ in [.tag(1, 2, 3)] }
                $0.git.hasBranch = { @Sendable _, _ in true }
                $0.git.revisionInfo = { @Sendable ref, _ in
                    if ref == .branch("main") { return . init(commit: "sha.main", date: .t0) }
                    if ref == .tag(1, 2, 3) { return .init(commit: "sha.1.2.3", date: .t1) }
                    fatalError("unknown ref: \(ref)")
                }
                $0.shell.run = { @Sendable cmd, _ in throw TestError.unknownCommand }
            } operation: {
                //setup
                let pkgId = UUID()
                do {
                    let pkg = Package(id: pkgId, url: "1".asGithubUrl.url)
                    try await pkg.save(on: app.db)
                    try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
                }
                let pkg = try await Package.fetchCandidate(app.db, id: pkgId)

                // MUT
                let delta = try await Analyze.diffVersions(client: app.client,
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
                #expect(delta.toDelete == [])
            }
        }
    }

    @Test func mergeReleaseInfo() async throws {
        // setup
        try await withApp { app in
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
            let versions: [Version] = try await [
                (Date(timeIntervalSince1970: 0), Reference.tag(1, 2, 3)),
                (Date(timeIntervalSince1970: 1), Reference.tag(2, 0, 0)),
                (Date(timeIntervalSince1970: 2), Reference.tag(2, 1, 0)),
                (Date(timeIntervalSince1970: 3), Reference.tag(2, 2, 0)),
                (Date(timeIntervalSince1970: 4), Reference.tag(2, 3, 0)),
                (Date(timeIntervalSince1970: 5), Reference.tag(2, 4, 0)),
                (Date(timeIntervalSince1970: 6), Reference.branch("main")),
            ].mapAsync { date, ref in
                let v = try Version(id: UUID(),
                                    package: pkg,
                                    commitDate: date,
                                    reference: ref)
                try await v.save(on: app.db)
                return v
            }
            let jpr = try await Package.fetchCandidate(app.db, id: .id0)

            // MUT
            Analyze.mergeReleaseInfo(package: jpr, into: versions)

            // validate
            let sortedResults = versions.sorted { $0.commitDate < $1.commitDate }
            #expect(sortedResults.map(\.releaseNotes) == ["rel 1.2.3", "rel 2.0.0", nil, nil, "rel 2.3.0", nil, nil])
            #expect(sortedResults.map(\.url) == ["", "", nil, nil, "some url", "", nil])
            #expect(sortedResults.map(\.publishedAt) == [Date(timeIntervalSince1970: 1),
                                                         Date(timeIntervalSince1970: 2),
                                                         nil, nil,
                                                         Date(timeIntervalSince1970: 4),
                                                         nil, nil])
        }
    }

    @Test func applyVersionDelta() async throws {
        // Ensure the existing default doc archives are preserved when replacing the default branch version
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2288
        try await withApp { app in
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
                #expect(try await Version.query(on: app.db).count() == 1)
                let v = try #require(await Version.query(on: app.db).first())
                #expect(v.docArchives == [.init(name: "foo", title: "Foo")])
            }
        }
    }

    @Test func applyVersionDelta_newRelease() async throws {
        // Ensure the existing default doc archives aren't copied over to a new release
        try await withApp { app in
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
                #expect(try await Version.query(on: app.db).count() == 2)
                let versions = try await Version.query(on: app.db).sort(\.$commit).all()
                #expect(versions[0].docArchives == [.init(name: "foo", title: "Foo")])
                #expect(versions[1].docArchives == nil)
            }
        }
    }

    @Test func getPackageInfo() async throws {
        // Tests getPackageInfo(package:version:)
        try await withApp { app in
            let commands = QueueIsolated<[String]>([])
            try await withDependencies {
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.shell.run = { @Sendable cmd, _ in
                    commands.withValue {
                        $0.append(cmd.description)
                    }
                    if cmd == .swiftDumpPackage {
                        return #"{ "name": "SPI-Server", "products": [], "targets": [] }"#
                    }
                    return ""
                }
            } operation: {
                // setup
                let pkg = try await savePackage(on: app.db, "https://github.com/foo/1")
                try await Repository(package: pkg, name: "1", owner: "foo").save(on: app.db)
                let version = try Version(id: UUID(), package: pkg, reference: .tag(.init(0, 4, 2)))
                try await version.save(on: app.db)
                let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)

                // MUT
                let info = try await Analyze.getPackageInfo(package: jpr, version: version)

                // validation
                #expect(commands.value == [
                    "git checkout 0.4.2 --quiet",
                    "swift package dump-package"
                ])
                #expect(info.packageManifest.name == "SPI-Server")
            }
        }
    }

    @Test func updateVersion() async throws {
        try await withApp { app in
            // setup
            let pkg = Package(id: UUID(), url: "1")
            try await pkg.save(on: app.db)
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
            _ = try await Analyze.updateVersion(on: app.db,
                                                version: version,
                                                packageInfo: .init(packageManifest: manifest, spiManifest: spiManifest))

            // read back and validate
            let v = try #require(await Version.query(on: app.db).first())
            #expect(v.packageName == "foo")
            #expect(v.resolvedDependencies?.map(\.packageName) == nil)
            #expect(v.swiftVersions == ["1", "2", "3.0.0"].asSwiftVersions)
            #expect(v.supportedPlatforms == [.ios("11.0"), .macos("10.10")])
            #expect(v.toolsVersion == "5.0.0")
            #expect(v.spiManifest == spiManifest)
        }
    }

    @Test func createProducts() async throws {
        try await withApp { app in
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
            try await p.save(on: app.db)
            try await v.save(on: app.db)

            // MUT
            try await Analyze.createProducts(on: app.db, version: v, manifest: m)

            // validation
            let products = try await Product.query(on: app.db).sort(\.$createdAt).all()
            #expect(products.map(\.name) == ["p1", "p2"])
            #expect(products.map(\.targets) == [["t1", "t2"], ["t3", "t4"]])
            #expect(products.map(\.type) == [.library(.automatic), .executable])
        }
    }

    @Test func createTargets() async throws {
        try await withApp { app in
            // setup
            let p = Package(id: UUID(), url: "1")
            let v = try Version(id: UUID(), package: p, packageName: "1", reference: .tag(.init(1, 0, 0)))
            let m = Manifest(name: "1",
                             products: [],
                             targets: [.init(name: "t1", type: .regular), .init(name: "t2", type: .executable)],
                             toolsVersion: .init(version: "5.0.0"))
            try await p.save(on: app.db)
            try await v.save(on: app.db)

            // MUT
            try await Analyze.createTargets(on: app.db, version: v, manifest: m)

            // validation
            let targets = try await Target.query(on: app.db).sort(\.$createdAt).all()
            #expect(targets.map(\.name) == ["t1", "t2"])
            #expect(targets.map(\.type) == [.regular, .executable])
        }
    }

    @Test func updatePackages() async throws {
        try await withApp { app in
            // setup
            let packages = try await savePackages(on: app.db, ["1", "2"].asURLs)
                .map(Joined<Package, Repository>.init(model:))
            let results: [Result<Joined<Package, Repository>, Error>] = [
                // feed in one error to see it passed through
                .failure(AppError.noValidVersions(try packages[0].model.requireID(), "1")),
                .success(packages[1])
            ]

            // MUT
            try await Analyze.updatePackages(client: app.client, database: app.db, results: results)

            // validate
            do {
                let packages = try await Package.query(on: app.db).sort(\.$url).all()
                assertEquals(packages, \.status, [.noValidVersions, .ok])
                assertEquals(packages, \.processingStage, [.analysis, .analysis])
            }
        }
    }

    @Test func issue_29() async throws {
        // Regression test for issue 29
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/29
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .now
                $0.environment.allowSocialPosts = { true }
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 12 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.getTags = { @Sendable _ in [.tag(1, 0, 0), .tag(2, 0, 0)] }
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
            } operation: {
                // setup
                let pkgs = try await savePackages(on: app.db, ["1", "2"].asGithubUrls.asURLs, processingStage: .ingestion)
                for pkg in pkgs {
                    try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
                }

                // MUT
                try await Analyze.analyze(client: app.client,
                                          database: app.db,
                                          mode: .limit(10))

                // validation
                // 1 version for the default branch + 2 for the tags each = 6 versions
                // 2 products per version = 12 products
                #expect(try await Version.query(on: app.db).count() == 6)
                #expect(try await Product.query(on: app.db).count() == 12)
            }
        }
    }

    @Test func issue_70() async throws {
        // Certain git commands fail when index.lock exists
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/70
        try await withApp { app in
            let commands = QueueIsolated<[String]>([])
            try await withDependencies {
                // claim every file exists, including our ficticious 'index.lock' for which
                // we want to trigger the cleanup mechanism
                $0.fileManager.fileExists = { @Sendable path in true }
                $0.shell.run = { @Sendable cmd, path in
                    commands.withValue { $0.append(cmd.description) }
                    return ""
                }
            } operation: {
                // setup
                try await savePackage(on: app.db, "1".asGithubUrl.url, processingStage: .ingestion)
                let pkgs = try await Package.fetchCandidates(app.db, for: .analysis, limit: 10)

                // MUT
                let res = await pkgs.mapAsync { @Sendable pkg in
                    await Result {
                        try await Analyze.refreshCheckout(package: pkg)
                    }
                }

                // validation
                #expect(res.map(\.isSuccess) == [true])
                assertSnapshot(of: commands.value, as: .dump)
            }
        }
    }

    @Test func issue_498() async throws {
        // git checkout can still fail despite git reset --hard + git clean
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/498
        try await withApp { app in
            let commands = QueueIsolated<[String]>([])
            try await withDependencies {
                // claim every file exists, including our ficticious 'index.lock' for which
                // we want to trigger the cleanup mechanism
                $0.fileManager.fileExists = { @Sendable path in true }
                $0.shell.run = { @Sendable cmd, path in
                    commands.withValue { $0.append(cmd.description) }
                    if cmd == .gitCheckout(branch: "master") {
                        throw TestError.simulatedCheckoutError
                    }
                    return ""
                }
            } operation: {
                // setup
                try await savePackage(on: app.db, "1".asGithubUrl.url, processingStage: .ingestion)
                let pkgs = try await Package.fetchCandidates(app.db, for: .analysis, limit: 10)

                // MUT
                let res = await pkgs.mapAsync { @Sendable pkg in
                    await Result {
                        try await Analyze.refreshCheckout(package: pkg)
                    }
                }

                // validation
                #expect(res.map(\.isSuccess) == [true])
                assertSnapshot(of: commands.value, as: .dump)
            }
        }
    }

    @Test func dumpPackage_5_4() async throws {
        // Test parsing a Package.swift that requires a 5.4 toolchain
        // NB: If this test fails on macOS make sure xcode-select -p
        // points to the correct version of Xcode!
        try await withDependencies {
            $0.fileManager.fileExists = FileManagerClient.liveValue.fileExists(atPath:)
            $0.logger = .noop
            $0.shell = .liveValue
        } operation: {
            // setup
            try await withTempDir { tempDir in
                let fixture = fixturesDirectory()
                    .appendingPathComponent("5.4-Package-swift").path
                let fname = tempDir.appending("/Package.swift")
                try await ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
                let m = try await Analyze.dumpPackage(at: tempDir)
                #expect(m.name == "VisualEffects")
            }
        }
    }

    @Test func dumpPackage_5_5() async throws {
        // Test parsing a Package.swift that requires a 5.5 toolchain
        // NB: If this test fails on macOS make sure xcode-select -p
        // points to the correct version of Xcode!
        // See also https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1441
        try await withDependencies {
            $0.fileManager.fileExists = FileManagerClient.liveValue.fileExists(atPath:)
            $0.logger = .noop
            $0.shell = .liveValue
        } operation: {
            // setup
            try await withTempDir { tempDir in
                let fixture = fixturesDirectory()
                    .appendingPathComponent("5.5-Package-swift").path
                let fname = tempDir.appending("/Package.swift")
                try await ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
                let m = try await Analyze.dumpPackage(at: tempDir)
                #expect(m.name == "Firestarter")
            }
        }
    }

    @Test func dumpPackage_5_9_macro_target() async throws {
        // Test parsing a 5.9 Package.swift with a macro target
        // NB: If this test fails on macOS make sure xcode-select -p
        // points to the correct version of Xcode!
        try await withDependencies {
            $0.fileManager.fileExists = FileManagerClient.liveValue.fileExists(atPath:)
            $0.logger = .noop
            $0.shell = .liveValue
        } operation: {
            // setup
            try await withTempDir { tempDir in
                let fixture = fixturesDirectory()
                    .appendingPathComponent("5.9-Package-swift").path
                let fname = tempDir.appending("/Package.swift")
                try await ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
                let m = try await Analyze.dumpPackage(at: tempDir)
                #expect(m.name == "StaticMemberIterable")
            }
        }
    }

    @Test func dumpPackage_format() async throws {
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
        try await withDependencies {
            $0.logger = .noop
        } operation: {
        try await withTempDir { @Sendable tempDir in
            let fixture = fixturesDirectory()
                .appendingPathComponent("5.9-Package-swift").path
            let fname = tempDir.appending("/Package.swift")
            try await ShellOut.shellOut(to: .copyFile(from: fixture, to: fname))
            var json = try await ShellClient.liveValue.run(command: .swiftDumpPackage, at: tempDir)
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
            assertSnapshot(of: json, as: .init(pathExtension: "json", diffing: .lines), named: "macos")
#elseif os(Linux)
            assertSnapshot(of: json, as: .init(pathExtension: "json", diffing: .lines), named: "linux")
#endif
        }
    }
    }

    @Test func issue_577() async throws {
        // Duplicate "latest release" versions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/577
        try await withApp { app in
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
                #expect(versions.map(\.reference.description) == ["1.2.3", "1.3.0"])
                #expect(versions.map(\.latest) == [nil, .release])
            }
        }
    }

    @Test func issue_693() async throws {
        // Handle moved tags
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/693
        try await withApp { app in
            let commands = QueueIsolated<[String]>([])
            try await withDependencies {
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.shell.run = { @Sendable cmd, _ in
                    commands.withValue { $0.append(cmd.description) }
                    if cmd == .gitFetchAndPruneTags { throw TestError.simulatedFetchError }
                    return ""
                }
            } operation: {
                // setup
                do {
                    let pkg = try await savePackage(on: app.db, id: .id0, "1".asGithubUrl.url)
                    try await Repository(package: pkg, defaultBranch: "main").save(on: app.db)
                }
                let pkg = try await Package.fetchCandidate(app.db, id: .id0)
                // MUT
                _ = try await Analyze.refreshCheckout(package: pkg)
                
                // validate
                assertSnapshot(of: commands.value, as: .dump)
            }
        }
    }

    @Test func updateLatestVersions() async throws {
        try await withApp { app in
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
                #expect(versions.map(\.reference.description) == ["main", "1.2.3", "2.0.0-rc1"])
                #expect(versions.map(\.latest) == [.defaultBranch, .release, .preRelease])
            }
        }
    }

    @Test func updateLatestVersions_old_beta() async throws {
        // Test to ensure outdated betas aren't picked up as latest versions
        // and that faulty db content (outdated beta marked as latest pre-release)
        // is correctly reset.
        // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/188
        try await withApp { app in
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
            #expect(versions.map(\.reference.description) == ["main", "2.0.0", "2.0.0-rc1"])
            #expect(versions.map(\.latest) == [.defaultBranch, .release, nil])
        }
    }

    @Test func issue_914() async throws {
        // Ensure we handle 404 repos properly
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/914
        try await withApp { app in
            // setup
            let checkoutDir = "/checkouts"
            let url = "1".asGithubUrl.url
            let repoDir = try await {
                let pkg = Package.init(url: url, processingStage: .ingestion)
                try await pkg.save(on: app.db)
                return try checkoutDir + "/" + #require(pkg.cacheDirectoryName)
            }()
            let lastUpdated = Date()

            try await withDependencies {
                $0.fileManager.fileExists = { @Sendable path in
                    if path.hasSuffix("github.com-foo-1") { return false }
                    return true
                }
                $0.shell.run = { @Sendable cmd, path in
                    if cmd == .gitClone(url: url, to: repoDir) {
                        struct ShellOutError: Error {}
                        throw ShellOutError()
                    }
                    throw TestError.unknownCommand
                }
            } operation: {
                // MUT
                try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(10))

                // validate
                let pkg = try await Package.query(on: app.db).first().unwrap()
                #expect(pkg.updatedAt! > lastUpdated)
                #expect(pkg.status == .analysisFailed)
            }
        }
    }

    @Test func trimCheckouts() throws {
        let removedPaths = NIOLockedValueBox<[String]>([])
        try withDependencies {
            $0.date.now = .t0
            $0.fileManager.attributesOfItem = { @Sendable path in
                [
                    "/checkouts/foo": [FileAttributeKey.modificationDate: Date.t0.adding(days: -31)],
                    "/checkouts/bar": [FileAttributeKey.modificationDate: Date.t0.adding(days: -29)],
                ][path]!
            }
            $0.fileManager.checkoutsDirectory = { "/checkouts" }
            $0.fileManager.contentsOfDirectory = { @Sendable _ in ["foo", "bar"] }
            $0.fileManager.removeItem = { @Sendable p in removedPaths.withLockedValue { $0.append(p) } }
        } operation: {
            // MUT
            try Analyze.trimCheckouts()

            // validate
            #expect(removedPaths.withLockedValue { $0 } == ["/checkouts/foo"])
        }
    }

    @Test func issue_2571_tags() async throws {
        // Ensure bad git commands do not delete existing tag revisions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2571
        try await withApp { app in
            try await withDependencies {
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 2 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.getTags = { @Sendable _ in throw TestError.unspecifiedError }
                $0.git.hasBranch = { @Sendable _, _ in true }
                $0.git.lastCommitDate = { @Sendable _ in .t1 }
                $0.git.shortlog = { @Sendable _ in
                """
                1\tPerson 1
                1\tPerson 2
                """
                }
                $0.shell.run = { @Sendable _, _ in "" }
            } operation: {
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

                try await withDependencies {  // first scenario: bad getTags
                    $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "", date: .t1) }
                } operation: {
                    // MUT
                    try await Analyze.analyze(client: app.client,
                                              database: app.db,
                                              mode: .limit(1))

                    // validate versions
                    let p = try await Package.find(pkgId, on: app.db).unwrap()
                    try await p.$versions.load(on: app.db)
                    let versions = p.versions.map(\.reference.description).sorted()
                    #expect(versions == ["1.0.0", "main"])
                }

                try await withDependencies {  // second scenario: revisionInfo throws
                    $0.git.getTags = { @Sendable _ in [.tag(1, 0, 0)] }
                    $0.git.revisionInfo = { @Sendable _, _ in throw TestError.unspecifiedError }
                } operation: {
                    // MUT
                    try await Analyze.analyze(client: app.client,
                                              database: app.db,
                                              mode: .limit(1))

                    // validate versions
                    let p = try await Package.find(pkgId, on: app.db).unwrap()
                    try await p.$versions.load(on: app.db)
                    let versions = p.versions.map(\.reference.description).sorted()
                    #expect(versions == ["1.0.0", "main"])
                }

                try await withDependencies {  // second scenario: gitTags throws
                    $0.git.getTags = { @Sendable _ in throw TestError.unspecifiedError }
                    $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "", date: .t1) }
                } operation: {
                    // MUT
                    try await Analyze.analyze(client: app.client,
                                              database: app.db,
                                              mode: .limit(1))

                    // validate versions
                    let p = try await Package.find(pkgId, on: app.db).unwrap()
                    try await p.$versions.load(on: app.db)
                    let versions = p.versions.map(\.reference.description).sorted()
                    #expect(versions == ["1.0.0", "main"])
                }

                try await withDependencies {  // third scenario: everything throws
                    $0.git.getTags = { @Sendable _ in throw TestError.unspecifiedError }
                    $0.git.revisionInfo = { @Sendable _, _ in throw TestError.unspecifiedError }
                    $0.shell.run = { @Sendable _, _ in throw TestError.unspecifiedError }
                } operation: {
                    // MUT
                    try await Analyze.analyze(client: app.client,
                                              database: app.db,
                                              mode: .limit(1))

                    // validate versions
                    let p = try await Package.find(pkgId, on: app.db).unwrap()
                    try await p.$versions.load(on: app.db)
                    let versions = p.versions.map(\.reference.description).sorted()
                    #expect(versions == ["1.0.0", "main"])
                }
            }
        }
    }

    @Test func issue_2571_latest_version() async throws {
        // Ensure `latest` remains set in case of AppError.noValidVersions
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2571
        let capturingLogger = CapturingLogger()
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .now
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 2 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.getTags = {@Sendable  _ in [.tag(1, 0, 0)] }
                $0.git.hasBranch = { @Sendable _, _ in true }
                $0.git.lastCommitDate = { @Sendable _ in .t1 }
                $0.git.shortlog = { @Sendable _ in
                """
                1\tPerson 1
                1\tPerson 2
                """
                }
                $0.logger = .testLogger(capturingLogger)
                $0.shell.run = { @Sendable _, _ in return "" }
            } operation: {
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
                struct Error: Swift.Error { }

                try await withDependencies {  // ensure happy path passes test (no revision changes)
                    $0.git.revisionInfo = { @Sendable ref, _ in
                        switch ref {
                            case .tag(.init(1, 0, 0), "1.0.0"):
                                return .init(commit: "commit0", date: .t0)
                            case .branch("main"):
                                return .init(commit: "commit0", date: .t0)
                            default:
                                throw Error()
                        }
                    }
                } operation: {
                    // MUT
                    try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(1))

                    // validate versions
                    let p = try await Package.find(pkgId, on: app.db).unwrap()
                    try await p.$versions.load(on: app.db)
                    let versions = p.versions.sorted(by: { $0.reference.description < $1.reference.description })
                    #expect(versions.map(\.reference.description) == ["1.0.0", "main"])
                    #expect(versions.map(\.latest) == [.release, .defaultBranch])
                }

                // make package available for analysis again
                pkg.processingStage = .ingestion
                try await pkg.save(on: app.db)

                try await withDependencies {  // simulate "main" branch moving forward to ("commit0", .t1)
                    $0.git.revisionInfo = { @Sendable ref, _ in
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
                    $0.shell.run = { @Sendable cmd, path in
                        // simulate error in getPackageInfo by failing checkout
                        if cmd == .gitCheckout(branch: "main") {
                            throw Error()
                        }
                        return ""
                    }
                } operation: {
                    // MUT
                    try await Analyze.analyze(client: app.client, database: app.db, mode: .limit(1))

                    // validate error logs
                    try capturingLogger.logs.withValue { logs in
                        #expect(logs.count == 2)
                        let error = try logs.last.unwrap()
                        #expect(error.message.contains("AppError.noValidVersions"), "was: \(error.message)")
                    }
                    // validate versions
                    let p = try await Package.find(pkgId, on: app.db).unwrap()
                    try await p.$versions.load(on: app.db)
                    let versions = p.versions.sorted(by: { $0.reference.description < $1.reference.description })
                    #expect(versions.map(\.reference.description) == ["1.0.0", "main"])
                    #expect(versions.map(\.latest) == [.release, .defaultBranch])
                }
            }
        }
    }

    @Test func issue_2873() async throws {
        // Ensure we preserve dependency counts from previous default branch version
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2873
        try await withApp { app in
            try await withDependencies {
                $0.date.now = .now
                $0.environment.loadSPIManifest = { _ in nil }
                $0.fileManager.fileExists = { @Sendable _ in true }
                $0.git.commitCount = { @Sendable _ in 12 }
                $0.git.firstCommitDate = { @Sendable _ in .t0 }
                $0.git.getTags = { @Sendable _ in [] }
                $0.git.hasBranch = { @Sendable _, _ in true }
                $0.git.lastCommitDate = { @Sendable _ in .t1 }
                $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha1", date: .t0) }
                $0.git.shortlog = { @Sendable _ in "10\tPerson 1" }
                $0.shell.run = { @Sendable cmd, path in
                    if cmd == .swiftDumpPackage { return .packageDump(name: "foo1") }
                    return ""
                }
            } operation: {
                // setup
                let pkg = try await savePackage(on: app.db, id: .id0, "https://github.com/foo/1".url, processingStage: .ingestion)
                try await Repository(package: pkg,
                                     defaultBranch: "main",
                                     name: "1",
                                     owner: "foo",
                                     stars: 100).save(on: app.db)

                // MUT and validation

                // first analysis pass
                try await Analyze.analyze(client: app.client, database: app.db, mode: .id(.id0))
                do { // validate
                    let pkg = try await Package.query(on: app.db).first()
                    // numberOfDependencies is nil here, because we've not yet received the info back from the build
                    #expect(pkg?.scoreDetails?.numberOfDependencies == nil)
                }

                do { // receive build report - we could send an actual report here via the API but let's just update
                     // the field directly instead, we're not testing build reporting after all
                    let version = try await Version.query(on: app.db).first()
                    version?.resolvedDependencies = .some([.init(packageName: "dep",
                                                                 repositoryURL: "https://github.com/some/dep")])
                    try await version?.save(on: app.db)
                }

                // second analysis pass
                try await Analyze.analyze(client: app.client, database: app.db, mode: .id(.id0))
                do { // validate
                    let pkg = try await Package.query(on: app.db).first()
                    // numberOfDependencies is 1 now, because we see the updated version
                    #expect(pkg?.scoreDetails?.numberOfDependencies == 1)
                }

                try await withDependencies {  // now we simulate a new version on the default branch
                    $0.git.revisionInfo = { @Sendable _, _ in .init(commit: "sha2", date: .t1) }
                } operation: {
                    // third analysis pass
                    try await Analyze.analyze(client: app.client, database: app.db, mode: .id(.id0))
                    do { // validate
                        let pkg = try await Package.query(on: app.db).first()
                        // numberOfDependencies must be preserved as 1, even though we've not built this version yet
                        #expect(pkg?.scoreDetails?.numberOfDependencies == 1)
                    }
                }
            }
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


private func assertEquals<Root, Value: Equatable>(_ values: [Root],
                                                  _ keyPath: KeyPath<Root, Value>,
                                                  _ expectations: [Value]) {
    #expect(values.map { $0[keyPath: keyPath] } == expectations,
            "\(values.map { $0[keyPath: keyPath] }) not equal to \(expectations)")
}

