@testable import App

import ShellOut
import XCTVapor


class GitTests: AppTestCase {

    static let tempDir = NSTemporaryDirectory().appending("spi-test-\(UUID())")
    static let errNoZip = fixturesDirectory().appendingPathComponent("ErrNo.zip").path


    override class func setUp() {
        try! Foundation.FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
        try! ShellOut.shellOut(to: .init("unzip \(errNoZip)"), at: tempDir)
    }

    override class func tearDown() {
        try? Foundation.FileManager.default.removeItem(atPath: tempDir)
    }

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

    func test_showDate() throws {
        Current.shell.run = mock(for: "git show -s --format=%ct 2c6399a1fa6f3b023bcdeac24b6a46ce3bd89ed0",
             """
             1536799579
             """
        )
        XCTAssertEqual(
            try Git.showDate("2c6399a1fa6f3b023bcdeac24b6a46ce3bd89ed0", at: "ignored"),
            Date(timeIntervalSince1970: 1536799579)
        )
    }

    func test_revInfo() throws {
        Current.shell.run = { cmd, _ in
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" 2.2.1"# {
                return "63c973f3c2e632a340936c285e94d59f9ffb01d5-1536799579"
            }
            throw TestError.unknownCommand
        }
        XCTAssertEqual(try Git.revisionInfo(.tag(.init(2, 2, 1)), at: "ignored"),
                       .init(commit: "63c973f3c2e632a340936c285e94d59f9ffb01d5",
                             date: Date(timeIntervalSince1970: 1536799579)))
    }

    func test_firstCommitDate() throws {
        Current.shell = .live
        XCTAssertEqual(try Git.firstCommitDate(at: "\(Self.tempDir)/ErrNo"),
                       Date(timeIntervalSince1970: 1426918070))  // Sat, 21 March 2015
    }

    func test_lastCommitDate() throws {
        Current.shell = .live
        XCTAssertEqual(try Git.lastCommitDate(at: "\(Self.tempDir)/ErrNo"),
                       Date(timeIntervalSince1970: 1554248253))  // Sat, 21 March 2015
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
