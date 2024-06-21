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
    
    
    func test_tag() async throws {
        Current.shell.run = mock(for: "git tag", """
            test
            1.0.0-pre
            1.0.0
            1.0.1
            1.0.2
            """
        )
        try await XCTAssertEqualAsync(
            try await Git.getTags(at: "ignored"), [
                .tag(.init(1, 0, 0, "pre")),
                .tag(.init(1, 0, 0)),
                .tag(.init(1, 0, 1)),
                .tag(.init(1, 0, 2)),
            ])
    }
    
    func test_revInfo() async throws {
        Current.shell.run = { cmd, _ in
            if cmd.description == #"git log -n1 --format=tformat:"%H-%ct" 2.2.1"# {
                return "63c973f3c2e632a340936c285e94d59f9ffb01d5-1536799579"
            }
            throw TestError.unknownCommand
        }
        try await XCTAssertEqualAsync(try await Git.revisionInfo(.tag(.init(2, 2, 1)), at: "ignored"),
                                      .init(commit: "63c973f3c2e632a340936c285e94d59f9ffb01d5",
                                            date: Date(timeIntervalSince1970: 1536799579)))
    }
    
    func test_revInfo_tagName() async throws {
        // Ensure we look up by tag name and not semver
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/139
        Current.shell.run = { cmd, _ in
            if cmd.description == #"git log -n1 --format=tformat:"%H-%ct" v2.2.1"# {
                return "63c973f3c2e632a340936c285e94d59f9ffb01d5-1536799579"
            }
            throw TestError.unknownCommand
        }
        try await XCTAssertEqualAsync(try await Git.revisionInfo(.tag(.init(2, 2, 1), "v2.2.1"), at: "ignored"),
                                      .init(commit: "63c973f3c2e632a340936c285e94d59f9ffb01d5",
                                            date: Date(timeIntervalSince1970: 1536799579)))
    }
    
}


private enum TestError: Error {
    case unknownCommand
}


func mock(for command: String, _ result: String) -> @Sendable (ShellOutCommand, String) throws -> String {
    { @Sendable cmd, path in
        guard cmd.description == command else { throw TestError.unknownCommand }
        return result
    }
}
