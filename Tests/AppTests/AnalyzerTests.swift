@testable import App

import Vapor
import XCTest


class AnalyzerTests: AppTestCase {
    
    func test_basic_analysis() throws {
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        try savePackages(on: app.db, urls.urls)
        var checkoutDir: String? = nil
        Current.fileManager.fileExists = { path in
            // let the check for the second repo checkout path succedd to simulate pull
            if let outDir = checkoutDir, path == "\(outDir)/github.com-foo-2" {
                return true
            }
            return false
        }
        Current.fileManager.createDirectory = { path, _, _ in
            checkoutDir = path
        }
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            commands.append(cmd.string)
            if cmd.string == "git tag" {
                return ["1.0", "1.1"].joined(separator: "\n")
            }
            return ""
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation
        let outDir = try XCTUnwrap(checkoutDir)
        XCTAssert(outDir.hasSuffix("SPI-checkouts"), "unexpected checkout dir, was: \(outDir)")
        XCTAssertEqual(commands,
                       ["git clone https://github.com/foo/1 \"\(outDir)/github.com-foo-1\" --quiet",
                        "git pull --quiet",
                        "git tag",
                        "git tag"]
        )
        let versions = try Version.query(on: app.db).all().wait()
        XCTAssertEqual(versions.compactMap(\.tagName).sorted(), ["1.0", "1.0", "1.1", "1.1"])
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
                return #"{ "name": "SPI-Server"}"#
            }
            return ""
        }
        let pkg = try savePackage(on: app.db, "https://github.com/foo/1".url)
        let version = try Version(id: UUID(), package: pkg, tagName: "0.4.2")
        try version.save(on: app.db).wait()

        // MUT
        let m = try getManifest(for: version, package: pkg)

        // validation
        XCTAssertEqual(commands, [
            "git checkout \"0.4.2\" --quiet",
            "swift package dump-package"
        ])
        XCTAssertEqual(m.name, "SPI-Server")
    }
}
