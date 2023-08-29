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

import XCTest

@testable import App

import ShellOut


// setup
class GitLiveTests: XCTestCase {
    static let tempDir = NSTemporaryDirectory().appending("spi-test-\(UUID())")
    static let sampleGitRepoName = "ErrNo"
    static let sampleGitRepoZipFile = fixturesDirectory()
        .appendingPathComponent("\(sampleGitRepoName).zip").path

    var path: String { "\(Self.tempDir)/\(Self.sampleGitRepoName)" }

    override class func setUp() {
        Current.shell = .live
        try! Foundation.FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: false, attributes: nil)
        try! ShellOut.shellOut(to: .init(command: "unzip", arguments: [sampleGitRepoZipFile.quoted]), at: tempDir)
    }

    override class func tearDown() {
        try? Foundation.FileManager.default.removeItem(atPath: tempDir)
    }
}


// Tests
extension GitLiveTests {

    func test_commitCount() throws {
        XCTAssertEqual(try Git.commitCount(at: path), 57)
    }

    func test_firstCommitDate() throws {
        XCTAssertEqual(try Git.firstCommitDate(at: path),
                       Date(timeIntervalSince1970: 1426918070))  // Sat, 21 March 2015
    }

    func test_lastCommitDate() throws {
        XCTAssertEqual(try Git.lastCommitDate(at: path),
                       Date(timeIntervalSince1970: 1554248253))  // Sat, 21 March 2015
    }

    func test_getTags() throws {
        XCTAssertEqual(
            try Git.getTags(at: path),
            [.tag(0,2,0),
             .tag(0,2,1),
             .tag(0,2,2),
             .tag(0,2,3),
             .tag(0,2,4),
             .tag(0,2,5),
             .tag(0,3,0),
             .tag(0,4,0),
             .tag(0,4,1),
             .tag(0,4,2),
             .tag(0,5,0),
             .tag(0,5,1),
             .tag(0,5,2),
             .tag(.init(0,0,1), "v0.0.1"),
             .tag(.init(0,0,2), "v0.0.2"),
             .tag(.init(0,0,3), "v0.0.3"),
             .tag(.init(0,0,4), "v0.0.4"),
             .tag(.init(0,0,5), "v0.0.5"),
             .tag(.init(0,1,0), "v0.1.0")]
        )
    }

    func test_showDate() throws {
        XCTAssertEqual(try Git.showDate("178566b112afe6bef3770678f1bbab6e5c626993",
                                        at: path).timeIntervalSince1970,
                       1554248253)  // April 2 23:37 UTC
    }

    func test_revisionInfo() throws {
        XCTAssertEqual(try Git.revisionInfo(.tag(0,5,2), at: path),
                       .init(commit: "178566b112afe6bef3770678f1bbab6e5c626993",
                             date: .init(timeIntervalSince1970: 1554248253)))
        XCTAssertEqual(try Git.revisionInfo(.branch("master"), at: path),
                       .init(commit: "178566b112afe6bef3770678f1bbab6e5c626993",
                             date: .init(timeIntervalSince1970: 1554248253)))
    }

    func test_shortlog() throws {
        XCTAssertEqual(try Git.shortlog(at: path), """
                36\tNeil Pankey
                21\tJacob Williams
            """)
    }

}
