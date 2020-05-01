@testable import App

import Vapor
import XCTest


class AnalyzerTests: AppTestCase {
    
    func test_basic_analysis() throws {
        // setup
        let urls = ["https://github.com/foo/1", "https://github.com/foo/2"]
        try savePackages(on: app.db, urls.urls)
        var checkoutDir: String? = nil
        Current.fileManager.fileExists = { _ in false }
        Current.fileManager.createDirectory = { path, _, _ in
            checkoutDir = path
        }
        var commands = [String]()
        Current.shell.run = { cmd, _ in
            commands.append(cmd.string)
        }

        // MUT
        try analyze(application: app, limit: 10).wait()

        // validation
        let outDir = try XCTUnwrap(checkoutDir)
        XCTAssert(outDir.hasSuffix("SPI-checkouts"), "unexpected checkout dir, was: \(outDir)")
        XCTAssertEqual(commands,
                       ["git clone https://github.com/foo/1 \"\(outDir)/github.com-foo-1\" --quiet",
                        "git clone https://github.com/foo/2 \"\(outDir)/github.com-foo-2\" --quiet"]
        )
    }

    // TODO: refresh checkout with error (continuation)
}
