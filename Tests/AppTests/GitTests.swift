@testable import App

import ShellOut
import XCTVapor


class GitTests: AppTestCase {

    func test_tag() throws {
        Current.shell.run = mock(for: "git tag",
             """
             test
             1.0.0-pre
             1.0.0
             1.0.1
             1.0.2
             """
        )
        XCTAssertEqual(
            try Git.tag(at: "ignored"), [
                .tag(.init(1, 0, 0, "pre")),
                .tag(.init(1, 0, 0)),
                .tag(.init(1, 0, 1)),
                .tag(.init(1, 0, 2)),
        ])
    }

    func test_revList() throws {
        Current.shell.run = mock(for: "git rev-list -n 1 2.2.1",
             """
             63c973f3c2e632a340936c285e94d59f9ffb01d5
             """
        )
        XCTAssertEqual(
            try Git.revList(.tag(.init(2, 2, 1)), at: "ignored"),
            "63c973f3c2e632a340936c285e94d59f9ffb01d5"
        )
    }
}


enum TestError: Error {
    case unknownCommand
}


func mock(for command: String, _ result: String) -> (ShellOutCommand, String) throws -> String {
    return { cmd, path in
        guard cmd.string == command else { throw TestError.unknownCommand }
        return result
    }
}
