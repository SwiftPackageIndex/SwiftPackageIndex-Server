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
    static var hasRunSetup = false

    override func setUp() async throws {
        // Simulate a class setUp (which does not exist as an async function)
        if Self.hasRunSetup { return }
        Self.hasRunSetup = true
        Current.shell = .live
        try! Foundation.FileManager.default.createDirectory(atPath: Self.tempDir, withIntermediateDirectories: false, attributes: nil)
        try! await ShellOut.shellOut(to: .init(command: "unzip", arguments: [Self.sampleGitRepoZipFile.quoted]), at: Self.tempDir)
    }

    override class func tearDown() {
        try? Foundation.FileManager.default.removeItem(atPath: tempDir)
    }
}


// Tests
extension GitLiveTests {

    func test_commitCount() async throws {
        try await XCTAssertEqualAsync(try await Git.commitCount(at: path), 57)
    }

    func test_firstCommitDate() async throws {
        try await XCTAssertEqualAsync(try await Git.firstCommitDate(at: path),
                                      Date(timeIntervalSince1970: 1426918070))  // Sat, 21 March 2015
    }

    func test_lastCommitDate() async throws {
        try await XCTAssertEqualAsync(try await Git.lastCommitDate(at: path),
                                      Date(timeIntervalSince1970: 1554248253))  // Sat, 21 March 2015
    }

    func test_getTags() async throws {
        try await XCTAssertEqualAsync(
            try await Git.getTags(at: path),
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

    func test_showDate() async throws {
        try await XCTAssertEqualAsync(try await Git.showDate("178566b112afe6bef3770678f1bbab6e5c626993",
                                                             at: path).timeIntervalSince1970,
                                      1554248253)  // April 2 23:37 UTC
    }

    func test_revisionInfo() async throws {
        try await XCTAssertEqualAsync(try await Git.revisionInfo(.tag(0,5,2), at: path),
                                      .init(commit: "178566b112afe6bef3770678f1bbab6e5c626993",
                                            date: .init(timeIntervalSince1970: 1554248253)))
        try await XCTAssertEqualAsync(try await Git.revisionInfo(.branch("master"), at: path),
                                      .init(commit: "178566b112afe6bef3770678f1bbab6e5c626993",
                                            date: .init(timeIntervalSince1970: 1554248253)))
    }

    func test_shortlog() async throws {
        try await XCTAssertEqualAsync(try await Git.shortlog(at: path), """
                36\tNeil Pankey
                21\tJacob Williams
            """)
    }

}
