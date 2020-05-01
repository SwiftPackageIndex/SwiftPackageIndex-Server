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

    // TODO: refresh checkout with error (continuation)

    // TODO: move to own file
    //    func test_parse_SemVer() throws {
    //        XCTAssertEqual(SemVer(string: "1.2.3"), SemVer(major: 1, minor: 2, patch: 3))
    //        XCTAssertEqual(SemVer(string: "1.2"), SemVer(major: 1, minor: 2, patch: 0))
    //        XCTAssertEqual(SemVer(string: "1"), SemVer(major: 1, minor: 0, patch: 0))
    //        XCTAssertEqual(SemVer(string: ""), nil)
    //        // FIXME: this should pass but currently equals SemVer("1.2.0")
    //        //        XCTAssertEqual(SemVer(string: "1.2.3rc"), nil)
    //    }

    //    func test_parse_version_output() throws {
    //        let str = """
    //            0.1.0
    //            0.1.1
    //            0.2.0
    //            """
    //        XCTAssertEqual(parseVersions(str), [
    //            SemVer("0.1.0"),
    //            SemVer("0.1.1"),
    //            SemVer("0.2.0"),
    //        ])
    //    }

    func test_reconcileVersions() throws {
        // TODO
    }
}
