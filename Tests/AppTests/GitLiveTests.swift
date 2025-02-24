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

import Foundation

@testable import App

import Dependencies
import ShellOut
import Testing


@Suite struct GitLiveTests {

    @Test func commitCount() async throws {
        try await withGitRepository(defaultDependencies) { path in
            try await XCTAssertEqualAsync(try await Git.commitCount(at: path), 57)
        }
    }

    @Test func firstCommitDate() async throws {
        try await withGitRepository(defaultDependencies) { path in
            try await XCTAssertEqualAsync(try await Git.firstCommitDate(at: path),
                                          Date(timeIntervalSince1970: 1426918070))  // Sat, 21 March 2015
        }
    }

    @Test func lastCommitDate() async throws {
        try await withGitRepository(defaultDependencies) { path in
            try await XCTAssertEqualAsync(try await Git.lastCommitDate(at: path),
                                          Date(timeIntervalSince1970: 1554248253))  // Sat, 21 March 2015
        }
    }

    @Test func getTags() async throws {
        try await withGitRepository(defaultDependencies) { path in
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
    }

    @Test func hasBranch() async throws {
        try await withGitRepository(defaultDependencies) { path in
            try await XCTAssertEqualAsync(try await Git.hasBranch(.branch("master"), at: path), true)
            try await XCTAssertEqualAsync(try await Git.hasBranch(.branch("main"), at: path), false)
        }
    }

    @Test func revisionInfo() async throws {
        try await withGitRepository(defaultDependencies) { path in
            try await XCTAssertEqualAsync(try await Git.revisionInfo(.tag(0,5,2), at: path),
                                          .init(commit: "178566b112afe6bef3770678f1bbab6e5c626993",
                                                date: .init(timeIntervalSince1970: 1554248253)))
            try await XCTAssertEqualAsync(try await Git.revisionInfo(.branch("master"), at: path),
                                          .init(commit: "178566b112afe6bef3770678f1bbab6e5c626993",
                                                date: .init(timeIntervalSince1970: 1554248253)))
        }
    }

    @Test func shortlog() async throws {
        try await withGitRepository(defaultDependencies) { path in
            try await XCTAssertEqualAsync(try await Git.shortlog(at: path), """
                36\tNeil Pankey
                21\tJacob Williams
            """)
        }
    }

}


private func withGitRepository(
    _ updateValuesForOperation: (inout DependencyValues) async throws -> Void = { _ in },
    _ test: (_ zipFilePath: String) async throws -> Void
) async throws {
    try await withDependencies(updateValuesForOperation) {
        try await withTempDir { tempDir in
            let fixtureFile = fixturesDirectory().appendingPathComponent("ErrNo.zip").path
            try await ShellOut.shellOut(to: .init(command: "unzip", arguments: [fixtureFile]), at: tempDir)
            let path = "\(tempDir)/ErrNo"
            try await test(path)
        }
    }
}


extension GitLiveTests {
#if compiler(>=6.1)
#warning("Move this into a trait on @Test")
    // See https://forums.swift.org/t/converting-xctest-invoketest-to-swift-testing/77692/4 for details
#endif
    var defaultDependencies: (inout DependencyValues) async throws -> Void {
        {
            $0.logger.log = { @Sendable _, _ in }
            $0.shell = .liveValue
        }
    }
}
