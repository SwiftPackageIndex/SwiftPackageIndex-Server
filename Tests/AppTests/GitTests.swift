// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import ShellOut
import XCTVapor


class GitTests: XCTestCase {

    static let tempDir = NSTemporaryDirectory().appending("spi-test-\(UUID())")
    static let sampleGitRepoName = "ErrNo"
    static let sampleGitRepoZipFile = fixturesDirectory()
        .appendingPathComponent("\(sampleGitRepoName).zip").path

    override class func setUp() {
        try! Foundation.FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
        try! ShellOut.shellOut(to: .init(command: "unzip", arguments: [sampleGitRepoZipFile.quoted]), at: tempDir)
    }

    override class func tearDown() {
        try? Foundation.FileManager.default.removeItem(atPath: tempDir)
    }

    func test_tag() throws {
        Current.shell.run = mock(for: "git tag", """
            test
            1.0.0-pre
            1.0.0
            1.0.1
            1.0.2
            """
        )
        XCTAssertEqual(
            try Git.getTags(at: "ignored"), [
                .tag(.init(1, 0, 0, "pre")),
                .tag(.init(1, 0, 0)),
                .tag(.init(1, 0, 1)),
                .tag(.init(1, 0, 2)),
            ])
    }

    func test_showDate() throws {
        Current.shell.run = mock(
            for: #"git show -s --format=%ct "2c6399a1fa6f3b023bcdeac24b6a46ce3bd89ed0""#, """
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
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "2.2.1""# {
                return "63c973f3c2e632a340936c285e94d59f9ffb01d5-1536799579"
            }
            throw TestError.unknownCommand
        }
        XCTAssertEqual(try Git.revisionInfo(.tag(.init(2, 2, 1)), at: "ignored"),
                       .init(commit: "63c973f3c2e632a340936c285e94d59f9ffb01d5",
                             date: Date(timeIntervalSince1970: 1536799579)))
    }

    func test_revInfo_tagName() throws {
        // Ensure we look up by tag name and not semver
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/139
        Current.shell.run = { cmd, _ in
            if cmd.string == #"git log -n1 --format=format:"%H-%ct" "v2.2.1""# {
                return "63c973f3c2e632a340936c285e94d59f9ffb01d5-1536799579"
            }
            throw TestError.unknownCommand
        }
        XCTAssertEqual(try Git.revisionInfo(.tag(.init(2, 2, 1), "v2.2.1"), at: "ignored"),
                       .init(commit: "63c973f3c2e632a340936c285e94d59f9ffb01d5",
                             date: Date(timeIntervalSince1970: 1536799579)))
    }

    func test_firstCommitDate() throws {
        Current.shell = .live
        XCTAssertEqual(try Git.firstCommitDate(at: "\(Self.tempDir)/\(Self.sampleGitRepoName)"),
                       Date(timeIntervalSince1970: 1426918070))  // Sat, 21 March 2015
    }

    func test_lastCommitDate() throws {
        Current.shell = .live
        XCTAssertEqual(try Git.lastCommitDate(at: "\(Self.tempDir)/\(Self.sampleGitRepoName)"),
                       Date(timeIntervalSince1970: 1554248253))  // Sat, 21 March 2015
    }

    func test_commitCount() throws {
        Current.shell = .live
        XCTAssertEqual(try Git.commitCount(at: "\(Self.tempDir)/\(Self.sampleGitRepoName)"), 57)
    }

    func test_shortlog() throws {
        Current.shell = .live
        XCTAssertEqual(try Git.shortlog(at: "\(Self.tempDir)/\(Self.sampleGitRepoName)"), """
                36\tNeil Pankey
                21\tJacob Williams
            """)
    }

}


private enum TestError: Error {
    case unknownCommand
}


func mock(for command: String, _ result: String) -> (ShellOutCommand, String) throws -> String {
    return { cmd, path in
        guard cmd.string == command else { throw TestError.unknownCommand }
        return result
    }
}
