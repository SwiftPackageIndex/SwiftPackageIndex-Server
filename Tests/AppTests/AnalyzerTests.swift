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
            .init(command: "env GIT_TERMINAL_PROMPT=0 git clone https://github.com/foo/1 \"\(outDir)/github.com-foo-1\" --quiet",
                path: outDir),
            .init(command: "git reset --hard", path: path2),
            .init(command: "git checkout \"master\" --quiet", path: path2),
            .init(command: "env GIT_TERMINAL_PROMPT=0 git pull --quiet", path: path2),
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
        // TODO: This is monstrous... create a helper? There has to be a better way?
        let pkg1 = try Package.query(on: app.db).filter(by: urls[0].url).with(\.$versions).first().wait()!
        XCTAssertEqual(pkg1.status, .ok)
        XCTAssertEqual(pkg1.processingStage, .analysis)
        XCTAssertEqual(pkg1.versions.map(\.packageName), ["foo-1", "foo-1"])
        XCTAssertEqual(pkg1.versions.sorted(by: { $0.createdAt! < $1.createdAt! }).map(\.tagName),
                       ["1.0.0", "1.1.1"])
        let pkg2 = try Package.query(on: app.db).filter(by: urls[1].url).with(\.$versions).first().wait()!
        XCTAssertEqual(pkg2.status, .ok)
        XCTAssertEqual(pkg2.processingStage, .analysis)
        XCTAssertEqual(pkg2.versions.map(\.packageName), ["foo-2", "foo-2"])
        XCTAssertEqual(pkg2.versions.sorted(by: { $0.createdAt! < $1.createdAt! }).map(\.tagName),
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
        XCTAssertEqual(packages.map(\.status), [.analysisFailed, .ok])
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
        // TODO: perhaps find a better way to assert success than counting commands - Version count?
        XCTAssertEqual(commands.count, 14, "was: \(dump(commands))")
    }

    func test_reconcileVersions() throws {
        // TODO - test failure scenarios
        // TODO - test delete isolation
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
        let pkg = try savePackage(on: app.db, "https://github.com/foo/1".url)
        let version = try Version(id: UUID(), package: pkg, tagName: "0.4.2")
        try version.save(on: app.db).wait()

        // MUT
        let m = try getManifest(package: pkg, version: version).get()

        // validation
        XCTAssertEqual(commands, [
            "git checkout \"0.4.2\" --quiet",
            "swift package dump-package"
        ])
        XCTAssertEqual(m.name, "SPI-Server")
    }

    func test_updateVersion() throws {
        // setup
        let pkg = Package(id: UUID(), url: "1".url)
        try pkg.save(on: app.db).wait()
        let version = try Version(package: pkg)
        let manifest = Manifest(name: "foo",
                                platforms: [.init(platformName: .ios, version: "11.0"),
                                            .init(platformName: .macos, version: "10.10")],
                                products: [],
                                swiftLanguageVersions: ["1", "2", "3.0.0rc"])

        // MUT
        _ = try updateVersion(on: app.db, version: version, manifest: .success(manifest)).wait()

        // read back and validate
        let v = try Version.query(on: app.db).first().wait()!
        XCTAssertEqual(v.packageName, "foo")
        XCTAssertEqual(v.swiftVersions, ["1.0.0", "2.0.0"])
        XCTAssertEqual(v.supportedPlatforms, ["ios_11.0", "macos_10.10"])
    }

    func test_updateProducts() throws {
        // setup
        let p = Package(id: UUID(), url: "1".url, status: .none)
        let v = try Version(id: UUID(), package: p, tagName: "1.0.0", packageName: "1")
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
