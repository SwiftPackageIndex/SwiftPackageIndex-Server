@testable import App

import Vapor
import XCTest


class AnalyzerTests: AppTestCase {
    
    func test_basic_analysis() throws {
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        try savePackages(on: app.db, urls.urls, processingStage: .ingestion)
        var checkoutDir: String? = nil
        Current.fileManager.fileExists = { path in
            // let the check for the second repo checkout path succedd to simulate pull
            if let outDir = checkoutDir, path == "\(outDir)/github.com-foo-2" { return true }
            if path.hasSuffix("Package.swift") { return true }
            return false
        }
        Current.fileManager.createDirectory = { path, _, _ in checkoutDir = path }
        var commands = [Command]()
        Current.shell.run = { cmd, path in
            commands.append(.init(command: cmd.string, path: path))
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
            return ""
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation
        let outDir = try XCTUnwrap(checkoutDir)
        XCTAssert(outDir.hasSuffix("SPI-checkouts"), "unexpected checkout dir, was: \(outDir)")

        let path1 = "\(outDir)/github.com-foo-1"
        let path2 = "\(outDir)/github.com-foo-2"
        let expecations: [Command] = [
            // clone of pkg1 and pull of pkg2
            .init(command: "git clone https://github.com/foo/1 \"\(outDir)/github.com-foo-1\" --quiet",
                path: outDir),
            .init(command: "git reset --hard", path: path2),
            .init(command: "git checkout \"master\" --quiet", path: path2),
            .init(command: "git pull --quiet", path: path2),
            // next, both repos have their tags listed
            .init(command: "git tag", path: path1),
            .init(command: "git tag", path: path2),
            // then, each repo sees a git checkout and dump-package *per version*, i.e. twice
            //   - first repo
            .init(command: "git checkout \"1.0.0\" --quiet", path: path1),
            .init(command: "swift package dump-package", path: path1),
            .init(command: "git checkout \"1.1.1\" --quiet", path: path1),
            .init(command: "swift package dump-package", path: path1),
            //   - second repo
            .init(command: "git checkout \"2.0.0\" --quiet", path: path2),
            .init(command: "swift package dump-package", path: path2),
            .init(command: "git checkout \"2.1.0\" --quiet", path: path2),
            .init(command: "swift package dump-package", path: path2),
            ]
        assert(commands: commands, expectations: expecations)

        // validate versions
        // A bit awkward... create a helper? There has to be a better way?
        let pkg1 = try Package.query(on: app.db).filter(by: urls[0].url).with(\.$versions).first().wait()!
        XCTAssertEqual(pkg1.status, .ok)
        XCTAssertEqual(pkg1.processingStage, .analysis)
        XCTAssertEqual(pkg1.versions.map(\.packageName), ["foo-1", "foo-1"])
        XCTAssertEqual(pkg1.versions.sorted(by: { $0.createdAt! < $1.createdAt! }).map(\.reference?.description),
                       ["1.0.0", "1.1.1"])
        let pkg2 = try Package.query(on: app.db).filter(by: urls[1].url).with(\.$versions).first().wait()!
        XCTAssertEqual(pkg2.status, .ok)
        XCTAssertEqual(pkg2.processingStage, .analysis)
        XCTAssertEqual(pkg2.versions.map(\.packageName), ["foo-2", "foo-2"])
        XCTAssertEqual(pkg2.versions.sorted(by: { $0.createdAt! < $1.createdAt! }).map(\.reference?.description),
                       ["2.0.0", "2.1.0"])

        // validate products (each version has 2 products)
        let products = try Product.query(on: app.db).sort(\.$name).all().wait()
        XCTAssertEqual(products.count, 4)
        XCTAssertEqual(products[0].name, "p1")
        XCTAssertEqual(products[0].type, .executable)
        XCTAssertEqual(products[1].name, "p1")
        XCTAssertEqual(products[1].type, .executable)
        XCTAssertEqual(products[2].name, "p2")
        XCTAssertEqual(products[2].type, .library)
        XCTAssertEqual(products[3].name, "p2")
        XCTAssertEqual(products[3].type, .library)
    }

    func test_package_status() throws {
        // Ensure packages record success/error status
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        try savePackages(on: app.db, urls.urls, processingStage: .ingestion)
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
        try savePackages(on: app.db, urls.urls, processingStage: .ingestion)
        var checkoutDir: String? = nil
        Current.fileManager.fileExists = { path in
            // let the check for the second repo checkout path succedd to simulate pull
            if let outDir = checkoutDir, path == "\(outDir)/github.com-foo-2" { return true }
            if path.hasSuffix("Package.swift") { return true }
            return false
        }
        Current.fileManager.createDirectory = { path, _, _ in checkoutDir = path }
        var commands = [Command]()
        Current.shell.run = { cmd, path in
            commands.append(.init(command: cmd.string, path: path))
            if cmd.string == "git tag" {
                return ["1.0.0", "1.1.1"].joined(separator: "\n")
            }
            // returning a blank string will cause an exception when trying to
            // decode it as the manifest result - we use this to simulate errors
            return ""
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation (not in detail, this is just to ensure command count is as expected)
        // Test setup is identical to `test_basic_analysis` except for the Manifest JSON,
        // which we intentionally broke. Command count must remain the same.
        XCTAssertEqual(commands.count, 14, "was: \(dump(commands))")
        // 2 packages with 2 versions each -> 4 versions
        // (there is not default branch set for these packages, hence only tags create versions)
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 4)
    }

    func test_pullOrClone() throws {
        // setup
        try savePackages(on: app.db, ["1", "2".gh].urls, processingStage: .ingestion)
        let pkgs = Package.fetchCandidates(app.db, for: .analysis, limit: 10)

        // MUT
        let res = try pkgs.flatMap { pullOrClone(application: self.app, packages: $0) }.wait()

        // validation
        XCTAssertEqual(res.count, 2)
        XCTAssertEqual(res.map(\.isSuccess), [false, true])
    }

    func test_reconcileVersions_package() throws {
        //setup
        Current.shell.run = { cmd, _ in
            if cmd.string == "git tag" {
                return "1.2.3"
            }
            return ""
        }
        let pkg = Package(id: UUID(), url: "1".gh.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "master").save(on: app.db).wait()

        // MUT
        let versions = try reconcileVersions(application: app, package: pkg).wait()

        // validate
        assertEquals(versions, \.reference?.description, ["master", "1.2.3"])
    }

    func test_reconcileVersions_checkouts() throws {
        //setup
        Current.shell.run = { cmd, _ in
            if cmd.string == "git tag" {
                return "1.2.3"
            }
            return ""
        }
        let pkg = Package(id: UUID(), url: "1".gh.url)
        try pkg.save(on: app.db).wait()
        try Repository(package: pkg, defaultBranch: "master").save(on: app.db).wait()
        let checkouts: [Result<Package, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.invalidPackageUrl(nil, "some reason")),
            .success(pkg)
        ]

        // MUT
        let results = try reconcileVersions(application: app, checkouts: checkouts).wait()

        // validate
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map(\.isSuccess), [false, true])
        let (_, versions) = try XCTUnwrap(results.last).get()
        assertEquals(versions, \.reference?.description, ["master", "1.2.3"])
    }

    func test_getManifest() throws {
        // setup
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            commands.append(cmd.string);
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
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            commands.append(cmd.string);
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
        let results = getManifests(versions: versions)

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
                                swiftLanguageVersions: ["1", "2", "3.0.0rc"])

        // MUT
        _ = try updateVersion(on: app.db, version: version, manifest: manifest).wait()

        // read back and validate
        let v = try Version.query(on: app.db).first().wait()!
        XCTAssertEqual(v.packageName, "foo")
        XCTAssertEqual(v.swiftVersions, ["1", "2", "3.0.0rc"])
        XCTAssertEqual(v.supportedPlatforms, [.ios("11.0"), .macos("10.10")])
    }

    func test_updateProducts() throws {
        // setup
        let p = Package(id: UUID(), url: "1", status: .none)
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
                                swiftLanguageVersions: ["1", "2", "3.0.0rc"])

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
        XCTAssertEqual(v.swiftVersions, ["1", "2", "3.0.0rc"])
        XCTAssertEqual(v.supportedPlatforms, [.ios("11.0"), .macos("10.10")])
        let products = try Product.query(on: app.db).all().wait()
        XCTAssertEqual(products.count, 1)
        let p = try XCTUnwrap(products.first)
        XCTAssertEqual(p.name, "p1")
    }

    func test_updateStatus() throws {
        // setup
        let packages = try savePackages(on: app.db, ["1", "2"].urls)
        let results: [Result<Package, Error>] = [
            // feed in one error to see it passed through
            .failure(AppError.noValidVersions(try packages[0].requireID(), "1")),
            .success(packages[1])
        ]

        // MUT
        try updateStatus(application: app, results: results).wait()

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
            return ""
        }
        try savePackages(on: app.db, ["1", "2"].gh.urls, processingStage: .ingestion)

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation
        XCTAssertEqual(try Version.query(on: app.db).count().wait(), 4)
        XCTAssertEqual(try Product.query(on: app.db).count().wait(), 8)
    }

}


struct Command: Equatable, CustomStringConvertible {
    var command: String
    var path: String

    var description: String { "'\(command)' at path: '\(path)'" }
}


func assert(commands: [Command], expectations: [Command], file: StaticString = #file, line: UInt = #line) {
    XCTAssertEqual(commands.count, expectations.count, "was:\n\(dump(commands))", file: file, line: line)
    zip(commands, expectations).enumerated().forEach { idx, pair in
        let (cmd, exp) = pair
        XCTAssertEqual(cmd, exp, "⚠️ command \(idx) failed", file: file, line: line)
    }
}
