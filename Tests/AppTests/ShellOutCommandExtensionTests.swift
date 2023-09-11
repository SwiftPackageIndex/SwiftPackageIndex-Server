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
        XCTAssertEqual(ShellOutCommand.gitClean.description, "git clean -fdx")
    }

    func test_gitCommitCount() throws {
        XCTAssertEqual(ShellOutCommand.gitCommitCount.description, "git rev-list --count HEAD")
    }

    func test_gitFetch() throws {
        XCTAssertEqual(ShellOutCommand.gitFetchAndPruneTags.description, "git fetch --tags --prune-tags --prune")
    }

    func test_gitFirstCommitDate() throws {
        XCTAssertEqual(ShellOutCommand.gitFirstCommitDate.description,
                       #"git log --max-parents=0 -n1 --format=format:"%ct""#)
    }

    func test_gitLastCommitDate() throws {
        XCTAssertEqual(ShellOutCommand.gitLastCommitDate.description,
                       #"git log -n1 --format=format:"%ct""#)
    }

    func test_gitReset() throws {
        XCTAssertEqual(ShellOutCommand.gitReset(hard: true).description,
                       "git reset --hard")
        XCTAssertEqual(ShellOutCommand.gitReset(hard: false).description,
                       "git reset")
    }

    func test_gitReset_branch() throws {
        XCTAssertEqual(ShellOutCommand.gitReset(to: "foo", hard: true).description,
                       "git reset origin/foo --hard")
        XCTAssertEqual(ShellOutCommand.gitReset(to: "foo", hard: false).description,
                       "git reset origin/foo")
    }

    func test_gitRevisionInfo() throws {
        let dash = "-"
        XCTAssertEqual(
            ShellOutCommand
                .gitRevisionInfo(reference: .tag(1, 2, 3), separator: dash).description,
            #"git log -n1 --format=tformat:"%H\#(dash)%ct" 1.2.3"#
        )
        XCTAssertEqual(
            ShellOutCommand
                .gitRevisionInfo(reference: .branch("foo"), separator: dash).description,
            #"git log -n1 --format=tformat:"%H\#(dash)%ct" foo"#
        )
        XCTAssertEqual(
            ShellOutCommand
                .gitRevisionInfo(reference: .branch("ba\nd"), separator: dash).description,
            "git log -n1 --format=tformat:\"%H\(dash)%ct\" 'ba\nd'"
        )
    }

    func test_gitShowDate() throws {
        XCTAssertEqual(ShellOutCommand.gitShowDate("abc").description,
                       #"git show -s --format=%ct abc"#)
    }

    func test_gitListTags() throws {
        XCTAssertEqual(ShellOutCommand.gitListTags.description, "git tag")
    }

    func test_quoting() throws {
        XCTAssertEqual(
            ShellOutCommand.gitReset(to: "foo ; rm *", hard: false).description,
            "git reset origin/'foo ; rm *'"
        )
        XCTAssertEqual(
            ShellOutCommand.gitRevisionInfo(reference: .branch("foo ; rm *")).description,
            #"git log -n1 --format=tformat:"%H-%ct" 'foo ; rm *'"#
        )
        XCTAssertEqual(
            ShellOutCommand.gitShowDate("foo ; rm *").description,
            #"git show -s --format=%ct 'foo ; rm *'"#
        )
    }

}
