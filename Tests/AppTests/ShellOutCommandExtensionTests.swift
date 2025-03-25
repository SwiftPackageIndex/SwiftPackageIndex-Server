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
import Testing


extension AllTests.ShellOutCommandExtensionTests {

    @Test func gitClean() throws {
        #expect(ShellOutCommand.gitClean.description == "git clean -fdx")
    }

    @Test func gitCommitCount() throws {
        #expect(ShellOutCommand.gitCommitCount.description == "git rev-list --count HEAD")
    }

    @Test func gitFetch() throws {
        #expect(ShellOutCommand.gitFetchAndPruneTags.description == "git fetch --tags --prune-tags --prune")
    }

    @Test func gitFirstCommitDate() throws {
        #expect(ShellOutCommand.gitFirstCommitDate.description == #"git log --max-parents=0 -n1 --format=format:"%ct""#)
    }

    @Test func gitLastCommitDate() throws {
        #expect(ShellOutCommand.gitLastCommitDate.description == #"git log -n1 --format=format:"%ct""#)
    }

    @Test func gitReset() throws {
        #expect(ShellOutCommand.gitReset(hard: true).description == "git reset --hard")
        #expect(ShellOutCommand.gitReset(hard: false).description == "git reset")
    }

    @Test func gitReset_branch() throws {
        #expect(ShellOutCommand.gitReset(to: "foo", hard: true).description == "git reset origin/foo --hard")
        #expect(ShellOutCommand.gitReset(to: "foo", hard: false).description == "git reset origin/foo")
    }

    @Test func gitRevisionInfo() throws {
        let dash = "-"
        #expect(
            ShellOutCommand
                .gitRevisionInfo(reference: .tag(1, 2, 3), separator: dash).description == #"git log -n1 --format=tformat:"%H\#(dash)%ct" 1.2.3"#
        )
        #expect(
            ShellOutCommand
                .gitRevisionInfo(reference: .branch("foo"), separator: dash).description == #"git log -n1 --format=tformat:"%H\#(dash)%ct" foo"#
        )
        #expect(
            ShellOutCommand
                .gitRevisionInfo(reference: .branch("ba\nd"), separator: dash).description == "git log -n1 --format=tformat:\"%H\(dash)%ct\" 'ba\nd'"
        )
    }

    @Test func gitShowDate() throws {
        #expect(ShellOutCommand.gitShowDate("abc").description == #"git show -s --format=%ct abc"#)
    }

    @Test func gitListTags() throws {
        #expect(ShellOutCommand.gitListTags.description == "git tag")
    }

    @Test func quoting() throws {
        #expect(
            ShellOutCommand.gitReset(to: "foo ; rm *", hard: false).description == "git reset origin/'foo ; rm *'"
        )
        #expect(
            ShellOutCommand.gitRevisionInfo(reference: .branch("foo ; rm *")).description == #"git log -n1 --format=tformat:"%H-%ct" 'foo ; rm *'"#
        )
        #expect(
            ShellOutCommand.gitShowDate("foo ; rm *").description == #"git show -s --format=%ct 'foo ; rm *'"#
        )
    }

}
