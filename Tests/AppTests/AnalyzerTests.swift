@testable import App

import Fluent
import SnapshotTesting
import Vapor
import XCTest


class AnalyzerTests: AppTestCase {
    
    func test_analyze() throws {
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        let pkgs = try savePackages(on: app.db, urls.asURLs, processingStage: .ingestion)
        try Repository(package: pkgs[0],
                       defaultBranch: "main",
                       name: "1",
                       owner: "foo",
                       stars: 25).save(on: app.db).wait()
        try Repository(package: pkgs[1],
                       defaultBranch: "main",
                       name: "2",
                       owner: "foo",
                       stars: 100).save(on: app.db).wait()
        var checkoutDir: String? = nil
        Current.fileManager.fileExists = { path in
            // let the check for the second repo checkout path succedd to simulate pull
            if let outDir = checkoutDir, path == "\(outDir)/github.com-foo-2" { return true }
            if path.hasSuffix("Package.swift") { return true }
            return false
        }
        Current.fileManager.createDirectory = { path, _, _ in checkoutDir = path }
        let queue = DispatchQueue(label: "serial")
        var commands = [Command]()
        Current.shell.run = { cmd, path in
            queue.sync {
                let c = cmd.string.replacingOccurrences(of: checkoutDir!, with: "...")
                let p = path.replacingOccurrences(of: checkoutDir!, with: "...")
                commands.append(.init(command: c, path: p))
            }
            if cmd.string == "git tag" && path.hasSuffix("foo-1") {
                return ["1.0.0", "1.1.1"].joined(separator: "\n")
            }
            if cmd.string == "git tag" && path.hasSuffix("foo-2") {
                return ["2.0.0", "2.1.0"].joined(separator: "\n")
            }
            if cmd.string == "swift package dump-package" && path.hasSuffix("foo-1") {
                return #"{ "name": "foo-1", "products": [{"name":"p1","type":{"executable": null}}] }"#
            }
            if cmd.string == "swift package dump-package" && path.hasSuffix("foo-2") {
                return #"{ "name": "foo-2", "products": [{"name":"p2","type":{"library": []}}] }"#
            }

            // Git.revisionInfo (per ref - default branch & tags)
            // These return a string in the format `commit sha`-`timestamp (sec since 1970)`
            // We simply use `fakesha` for the sha (it bears no meaning) and a range of seconds
            // since 1970.
            // It is important the tags aren't created at identical times for tags on the same
            // package, or else we will collect multiple recent releases (as there is no "latest")
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "1.0.0""# { return "fakesha-0" }
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "1.1.1""# { return "fakesha-1" }
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "2.0.0""# { return "fakesha-0" }
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "2.1.0""# { return "fakesha-1" }
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "main""# { return "fakesha-2" }

            // Git.commitCount
            if cmd.string == "git rev-list --count HEAD" { return "12" }

            // Git.firstCommitDate
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }

            // Git.lastCommitDate
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }

            return ""
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation
        let outDir = try XCTUnwrap(checkoutDir)
        XCTAssert(outDir.hasSuffix("SPI-checkouts"), "unexpected checkout dir, was: \(outDir)")
        XCTAssertEqual(commands.count, 31)
        // We need to sort the issued commands, because macOS and Linux have stable but different
        // sort orders o.O
        assertSnapshot(matching: commands.sorted(), as: .dump)

        // validate versions
        // A bit awkward... create a helper? There has to be a better way?
        let pkg1 = try Package.query(on: app.db).filter(by: urls[0].url).with(\.$versions).first().wait()!
        XCTAssertEqual(pkg1.status, .ok)
        XCTAssertEqual(pkg1.processingStage, .analysis)
        XCTAssertEqual(pkg1.versions.map(\.packageName), ["foo-1", "foo-1", "foo-1"])
        XCTAssertEqual(pkg1.versions.sorted(by: { $0.createdAt! < $1.createdAt! }).map(\.reference?.description),
                       ["main", "1.0.0", "1.1.1"])
        let pkg2 = try Package.query(on: app.db).filter(by: urls[1].url).with(\.$versions).first().wait()!
        XCTAssertEqual(pkg2.status, .ok)
        XCTAssertEqual(pkg2.processingStage, .analysis)
        XCTAssertEqual(pkg2.versions.map(\.packageName), ["foo-2", "foo-2", "foo-2"])
        XCTAssertEqual(pkg2.versions.sorted(by: { $0.createdAt! < $1.createdAt! }).map(\.reference?.description),
                       ["main", "2.0.0", "2.1.0"])

        // validate products (each version has 2 products)
        let products = try Product.query(on: app.db).sort(\.$name).all().wait()
        XCTAssertEqual(products.count, 6)
        assertEquals(products, \.name, ["p1", "p1", "p1", "p2", "p2", "p2"])
        assertEquals(products, \.type, [.executable, .executable, .executable, .library, .library, .library])

        // validate score
        XCTAssertEqual(pkg1.score, 10)
        XCTAssertEqual(pkg2.score, 20)

        // ensure stats, recent packages, and releases are refreshed
        XCTAssertEqual(try Stats.fetch(on: app.db).wait(), .init(packageCount: 2, versionCount: 6))
        XCTAssertEqual(try RecentPackage.fetch(on: app.db).wait().count, 2)
        XCTAssertEqual(try RecentRelease.fetch(on: app.db).wait().count, 2)
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
        Current.shell.run = { cmd, path in
            if cmd.string == "git tag" { return "1.0.0" }
            // first package fails
            if cmd.string == "swift package dump-package" && path.hasSuffix("foo-1") {
                return "bad data"
            }
            // second package succeeds
            if cmd.string == "swift package dump-package" && path.hasSuffix("foo-2") {
                return #"{ "name": "SPI-Server", "products": [] }"#
            }
            if cmd.string.hasPrefix(#"git log -n1 --format=format:"%H-%ct""#) { return "sha-0" }
            if cmd.string == "git rev-list --count HEAD" { return "12" }
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }
            return ""
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

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
        let queue = DispatchQueue(label: "serial")
        var commands = [Command]()
        Current.shell.run = { cmd, path in
            queue.sync {
                commands.append(.init(command: cmd.string, path: path))
            }
            if cmd.string == "git tag" {
                return ["1.0.0", "1.1.1"].joined(separator: "\n")
            }
            if cmd.string.hasPrefix(#"git log -n1 --format=format:"%H-%ct""#) { return "sha-0" }
            if cmd.string == "git rev-list --count HEAD" { return "12" }
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }
            // returning a blank string will cause an exception when trying to
            // decode it as the manifest result - we use this to simulate errors
            return ""
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation (not in detail, this is just to ensure command count is as expected)
        // Test setup is identical to `test_basic_analysis` except for the Manifest JSON,
        // which we intentionally broke. Command count must remain the same.
        XCTAssertEqual(commands.count, 31, "was: \(dump(commands))")
        // 2 packages with 2 tags + 1 default branch each -> 6 versions
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 6)
    }

    func test_pullOrClone() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".asGithubUrl.url)
        let queue = DispatchQueue(label: "serial")
        Current.fileManager.fileExists = { _ in true }
        var commands = [String]()
        Current.shell.run = { cmd, path in
            queue.sync {
                // mask variable checkout
                let checkoutDir = Current.fileManager.checkoutsDirectory()
                commands.append(cmd.string.replacingOccurrences(of: checkoutDir, with: "..."))
            }
            return ""
        }

        // MUT
        _ = try pullOrClone(application: app, package: pkg).wait()

        // validate
        XCTAssertEqual(commands, [
            #"rm "-f" ".../github.com-foo-1/.git/HEAD.lock""#,
            #"rm "-f" ".../github.com-foo-1/.git/index.lock""#,
            #"git reset --hard"#,
            #"git fetch"#,
            #"git checkout "master" --quiet"#,
            #"git pull --quiet"#,
        ])
    }

    func test_pullOrClone_continueOnError() throws {
        // Test that processing continues on if a url in invalid
        // setup - first URL is not a valid url
        try savePackages(on: app.db, ["1", "2".asGithubUrl].asURLs, processingStage: .ingestion)
        let pkgs = Package.fetchCandidates(app.db, for: .analysis, limit: 10)

        // MUT
        let res = try pkgs.flatMap { pullOrClone(application: self.app, packages: $0) }.wait()

        // validation
        XCTAssertEqual(res.count, 2)
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
    }

    func test_updateRepository() throws {
        // setup
        Current.shell.run = { cmd, _ in
            if cmd.string == "git rev-list --count HEAD" { return "12" }
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }
            throw TestError.unknownCommand
        }
        let pkg = Package(id: UUID(), url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "master").save(on: app.db).wait()
        _ = try pkg.$repositories.get(on: app.db).wait()

        // MUT
        let res = updateRepository(package: pkg)

        // validate
        let repo = try XCTUnwrap(try res.get().repository)
        XCTAssertEqual(repo.commitCount, 12)
        XCTAssertEqual(repo.firstCommitDate, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(repo.lastCommitDate, Date(timeIntervalSince1970: 1))
    }

    func test_updateRepositories() throws {
        // setup
        Current.shell.run = { cmd, _ in
            if cmd.string == "git rev-list --count HEAD" { return "12" }
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }
            throw TestError.unknownCommand
        }
        let pkg = Package(id: UUID(), url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "master").save(on: app.db).wait()
        _ = try pkg.$repositories.get(on: app.db).wait()
        let checkouts: [Result<Package, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.invalidPackageUrl(nil, "some reason")),
            .success(pkg)
        ]

        // MUT
        let results: [Result<Package, Error>] =
            try updateRepositories(application: app, checkouts: checkouts).wait()

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

    func test_reconcileVersions_package() throws {
        //setup
        Current.shell.run = { cmd, _ in
            if cmd.string == "git tag" {
                return "1.2.3"
            }
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "master""# { return "sha.master-0" }
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "1.2.3""# { return "sha.1.2.3-1" }
            throw TestError.unknownCommand
        }
        let pkg = Package(id: UUID(), url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "master").save(on: app.db).wait()

        // MUT
        let versions = try reconcileVersions(application: app,
                                             transaction: app.db,
                                             package: pkg).wait()

        // validate
        assertEquals(versions, \.reference?.description, ["master", "1.2.3"])
        assertEquals(versions, \.commit, ["sha.master", "sha.1.2.3"])
        assertEquals(versions, \.commitDate,
                     [Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 1)])
    }

    func test_reconcileVersions_checkouts() throws {
        //setup
        Current.shell.run = { cmd, _ in
            if cmd.string == "git tag" {
                return "1.2.3"
            }
            if cmd.string.hasPrefix(#"git log -n1 --format=format:"%H-%ct""#) { return "sha-0" }
            return ""
        }
        let pkg = Package(id: UUID(), url: "1".asGithubUrl.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "master").save(on: app.db).wait()
        let checkouts: [Result<Package, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.invalidPackageUrl(nil, "some reason")),
            .success(pkg)
        ]

        // MUT
        let results = try reconcileVersions(application: app,
                                            transaction: app.db,
                                            checkouts: checkouts).wait()

        // validate
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map(\.isSuccess), [false, true])
        let (_, versions) = try XCTUnwrap(results.last).get()
        assertEquals(versions, \.reference?.description, ["master", "1.2.3"])
    }

    func test_getManifest() throws {
        // setup
        let queue = DispatchQueue(label: "serial")
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            queue.sync {
                commands.append(cmd.string)
            }
            if cmd.string == "swift package dump-package" {
                return #"{ "name": "SPI-Server", "products": [] }"#
            }
            return ""
        }
        let pkg = try savePackage(on: app.db, "https://github.com/foo/1")
        let version = try Version(id: UUID(), package: pkg, reference: .tag(.init(0, 4, 2)))
        try version.save(on: app.db).wait()

        // MUT
        let (v, m) = try getManifest(package: pkg, version: version).get()

        // validation
        XCTAssertEqual(commands, [
            "git checkout \"0.4.2\" --quiet",
            "swift package dump-package"
        ])
        XCTAssertEqual(v.id, version.id)
        XCTAssertEqual(m.name, "SPI-Server")
    }

    func test_getManifests() throws {
        // setup
        let queue = DispatchQueue(label: "serial")
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            queue.sync {
                commands.append(cmd.string)
            }
            if cmd.string == "swift package dump-package" {
                return #"{ "name": "SPI-Server", "products": [] }"#
            }
            return ""
        }
        let pkg = try savePackage(on: app.db, "https://github.com/foo/1")
        let version = try Version(id: UUID(), package: pkg, reference: .tag(.init(0, 4, 2)))
        try version.save(on: app.db).wait()

        let versions: [Result<(Package, [Version]), Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.invalidPackageUrl(nil, "some reason")),
            .success((pkg, [version]))
        ]

        // MUT
        let results = getManifests(logger: app.logger, versions: versions)

        // validation
        XCTAssertEqual(commands, [
            "git checkout \"0.4.2\" --quiet",
            "swift package dump-package"
        ])
        XCTAssertEqual(results.map(\.isSuccess), [false, true])
        let (_, versionsManifests) = try XCTUnwrap(results.last).get()
        XCTAssertEqual(versionsManifests.count, 1)
        let (v, m) = try XCTUnwrap(versionsManifests.first)
        XCTAssertEqual(v, version)
        XCTAssertEqual(m.name, "SPI-Server")
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
                                swiftLanguageVersions: ["1", "2", "3.0.0"])

        // MUT
        _ = try updateVersion(on: app.db, version: version, manifest: manifest).wait()

        // read back and validate
        let v = try Version.query(on: app.db).first().wait()!
        XCTAssertEqual(v.packageName, "foo")
        XCTAssertEqual(v.swiftVersions, ["1", "2", "3.0.0"].asSwiftVersions)
        XCTAssertEqual(v.supportedPlatforms, [.ios("11.0"), .macos("10.10")])
    }

    func test_updateProducts() throws {
        // setup
        let p = Package(id: UUID(), url: "1")
        let v = try Version(id: UUID(), package: p, reference: .tag(.init(1, 0, 0)), packageName: "1")
        let m = Manifest(name: "1", products: [.init(name: "p1", type: .library),
                                               .init(name: "p2", type: .executable)])
        try p.save(on: app.db).wait()
        try v.save(on: app.db).wait()

        // MUT
        try updateProducts(on: app.db, version: v, manifest: m).wait()

        // validation
        let products = try Product.query(on: app.db).sort(\.$createdAt).all().wait()
        XCTAssertEqual(products.map(\.name), ["p1", "p2"])
    }

    func test_updateVersionsAndProducts() throws {
        // setup
        let pkg = Package(id: UUID(), url: "1")
        try pkg.save(on: app.db).wait()
        let version = try Version(package: pkg)
        let manifest = Manifest(name: "foo",
                                platforms: [.init(platformName: .ios, version: "11.0"),
                                            .init(platformName: .macos, version: "10.10")],
                                products: [.init(name: "p1", type: .library)],
                                swiftLanguageVersions: ["1", "2", "3.0.0"])

        let results: [Result<(Package, [(Version, Manifest)]), Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.noValidVersions(nil, "some url")),
            .success((pkg, [(version, manifest)]))
        ]

        // MUT
        let res = try updateVersionsAndProducts(on: app.db, results: results).wait()

        // validation
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
        // read back and validate
        let versions = try Version.query(on: app.db).all().wait()
        XCTAssertEqual(versions.count, 1)
        let v = try XCTUnwrap(versions.first)
        XCTAssertEqual(v.packageName, "foo")
        XCTAssertEqual(v.swiftVersions, ["1", "2", "3.0.0"].asSwiftVersions)
        XCTAssertEqual(v.supportedPlatforms, [.ios("11.0"), .macos("10.10")])
        let products = try Product.query(on: app.db).all().wait()
        XCTAssertEqual(products.count, 1)
        let p = try XCTUnwrap(products.first)
        XCTAssertEqual(p.name, "p1")
    }

    func test_updatePackage() throws {
        // setup
        let packages = try savePackages(on: app.db, ["1", "2"].asURLs)
        let results: [Result<Package, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.noValidVersions(try packages[0].requireID(), "1")),
            .success(packages[1])
        ]

        // MUT
        try updatePackage(application: app, results: results, stage: .analysis).wait()

        // validate
        do {
            let packages = try Package.query(on: app.db).sort(\.$url).all().wait()
            assertEquals(packages, \.status, [.noValidVersions, .ok])
            assertEquals(packages, \.processingStage, [.analysis, .analysis])
        }
    }

    func test_issue_42() throws {
        // setup
        Current.shell.run = { cmd, path in
            if cmd.string == "git tag" {
                return ["1.0.0", "2.0.0"].joined(separator: "\n")
            }
            if cmd.string == "swift package dump-package" {
                return #"{ "name": "foo", "products": [{"name":"p1","type":{"executable": null}}, {"name":"p2","type":{"executable": null}}] }"#
            }
            if cmd.string.hasPrefix(#"git log -n1 --format=format:"%H-%ct""#) { return "sha-0" }
            if cmd.string == "git rev-list --count HEAD" { return "12" }
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }
            return ""
        }
        let pkgs = try savePackages(on: app.db, ["1", "2"].asGithubUrls.asURLs, processingStage: .ingestion)
        try pkgs.forEach {
            try Repository(package: $0, defaultBranch: "master").save(on: app.db).wait()
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

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

        let queue = DispatchQueue(label: "serial")
        var commands = [String]()
        Current.shell.run = { cmd, path in
            queue.sync {
                let c = cmd.string.replacingOccurrences(of: checkoutDir, with: "...")
                commands.append(c)
            }
            return ""
        }

        // MUT
        let res = try pkgs.flatMap { pullOrClone(application: self.app, packages: $0) }.wait()

        // validation
        XCTAssertEqual(res.map(\.isSuccess), [true])
        assertSnapshot(matching: commands, as: .dump)
    }
}


struct Command: Equatable, CustomStringConvertible, Hashable, Comparable {
    var command: String
    var path: String

    var description: String { "'\(command)' at path: '\(path)'" }

    static func < (lhs: Command, rhs: Command) -> Bool {
        if lhs.command < rhs.command { return true }
        return lhs.path < rhs.path
    }
}
