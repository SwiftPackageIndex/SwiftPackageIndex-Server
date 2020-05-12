@testable import App

import ShellOut
import XCTVapor


class RegressionTests: XCTestCase {

    func test_issue_58_git_prompt_crash() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/58
        try XCTSkipIf(isRunningInCI)  // doesn't work in CI

        Current.shell = .live
        Current.fileManager = .live
        // specifying a non-existant repo will trigger a 404, which will trigger a prompt
        // unfortunately, this does *not* reproduce the hanging when prompts are allowed,
        // presumably because the test runs without interactive terminal
        let pkg = Package(url: "https://github.com/foo-nonexistant/bar.git")
        let cacheDir = try XCTUnwrap(Current.fileManager.cacheDirectoryPath(for: pkg))
        let wdir = Current.fileManager.checkoutsDirectory
        XCTAssertThrowsError(
            try Current.shell.run(command: .gitClone(url: URL(string: pkg.url)!, to: cacheDir), at: wdir)
        ) { error in
            let e = error as? ShellOutError
            XCTAssertEqual(e?.message, "fatal: could not read Username for 'https://github.com': Device not configured")
        }
    }

}
