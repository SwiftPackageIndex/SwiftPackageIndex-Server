@testable import App

import ShellOut
import XCTVapor


class RegressionTests: XCTestCase {

    func test_issue_58_git_prompt_crash() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/58
        Current.shell = .live
        Current.fileManager = .live
        let pkg = Package(url: "https://github.com/SwiftyBeaver/AES256CBC.git")
        let cacheDir = try XCTUnwrap(Current.fileManager.cacheDirectoryPath(for: pkg))
        let wdir = Current.fileManager.checkoutsDirectory
        XCTAssertThrowsError(
            try Current.shell.run(command: .gitClone(url: URL(string: pkg.url)!, to: cacheDir, allowingPrompt: false), at: wdir)
        ) { error in
            let e = error as? ShellOutError
            XCTAssertEqual(e?.message, "fatal: could not read Username for 'https://github.com': terminal prompts disabled")
        }
    }

}
