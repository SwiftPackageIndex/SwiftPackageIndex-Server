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
        var commands = [Command]()
        Current.shell.run = { cmd, path in
            commands.append(.init(command: cmd.string, path: path))
            if cmd.string == "git tag" {
                return ["1.0", "1.1"].joined(separator: "\n")
            }
            if cmd.string == "swift package dump-package" {
                return #"{ "name": "SPI-Server"}"#
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
                path: "."),  // "outDir" is translated to "." in this context
            .init(command: "git pull --quiet", path: path2),
            // next, both repos have their tags listed
            .init(command: "git tag", path: path1),
            .init(command: "git tag", path: path2),
            // then, each repo sees a git checkout and dump-package *per version*, i.e. twice
            //   - first repo
            .init(command: "git checkout \"1.0\" --quiet", path: path1),
            .init(command: "swift package dump-package", path: path1),
            .init(command: "git checkout \"1.1\" --quiet", path: path1),
            .init(command: "swift package dump-package", path: path1),
            //   - second repo
            .init(command: "git checkout \"1.0\" --quiet", path: path2),
            .init(command: "swift package dump-package", path: path2),
            .init(command: "git checkout \"1.1\" --quiet", path: path2),
            .init(command: "swift package dump-package", path: path2),
            ]
        assert(commands: commands, expectations: expecations)

        let versions = try Version.query(on: app.db).all().wait()
        // TODO: filter by package
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
        let m = try getManifest(package: pkg, version: version)

        // validation
        XCTAssertEqual(commands, [
            "git checkout \"0.4.2\" --quiet",
            "swift package dump-package"
        ])
        XCTAssertEqual(m.name, "SPI-Server")
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
