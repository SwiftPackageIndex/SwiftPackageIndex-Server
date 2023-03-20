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

import XCTest
import ShellOut


class ShellOutCommandExtensionTests: XCTestCase {

    func test_gitClean() throws {
        XCTAssertEqual(ShellOutCommand.gitClean.string, "git clean -fdx")
    }

    func test_gitCommitCount() throws {
        XCTAssertEqual(ShellOutCommand.gitCommitCount.string, "git rev-list --count HEAD")
    }

    func test_gitFetch() throws {
        XCTAssertEqual(ShellOutCommand.gitFetchAndPruneTags.string, "git fetch --tags --prune-tags --prune")
    }

    func test_gitFirstCommitDate() throws {
        XCTAssertEqual(ShellOutCommand.gitFirstCommitDate.string,
                       #"git log --max-parents=0 -n1 --format=format:"%ct""#)
    }

    func test_gitLastCommitDate() throws {
        XCTAssertEqual(ShellOutCommand.gitLastCommitDate.string,
                       #"git log -n1 --format=format:"%ct""#)
    }

    func test_gitReset() throws {
        XCTAssertEqual(ShellOutCommand.gitReset(hard: true).string,
                       "git reset --hard")
        XCTAssertEqual(ShellOutCommand.gitReset(hard: false).string,
                       "git reset")
    }

    func test_gitReset_branch() throws {
        XCTAssertEqual(ShellOutCommand.gitReset(to: "foo", hard: true).string,
                       #"git reset "origin/foo" --hard"#)
        XCTAssertEqual(ShellOutCommand.gitReset(to: "foo", hard: false).string,
                       #"git reset "origin/foo""#)
    }

    func test_gitRevisionInfo() throws {
        let dash = "-"
        XCTAssertEqual(
            ShellOutCommand
                .gitRevisionInfo(reference: .tag(1, 2, 3), separator: dash).string,
            #"git log -n1 --format=format:"%H\#(dash)%ct" "1.2.3""#
        )
        XCTAssertEqual(
            ShellOutCommand
                .gitRevisionInfo(reference: .branch("foo"), separator: dash).string,
            #"git log -n1 --format=format:"%H\#(dash)%ct" "foo""#
        )
        XCTAssertEqual(
            ShellOutCommand
                .gitRevisionInfo(reference: .branch("ba\nd"), separator: dash).string,
            #"git log -n1 --format=format:"%H\#(dash)%ct" "bad""#
        )
    }

    func test_gitShowDate() throws {
        XCTAssertEqual(ShellOutCommand.gitShowDate("abc").string,
                       #"git show -s --format=%ct "abc""#)
    }

    func test_gitListTags() throws {
        XCTAssertEqual(ShellOutCommand.gitListTags.string, "git tag")
    }

}
