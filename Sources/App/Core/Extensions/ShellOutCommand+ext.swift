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
import ShellOut


// MARK: Git commands


extension ShellOutCommand {

    static var gitClean: Self {
        .init(command: .git, arguments: ["clean", "-fdx"])
    }

    static var gitCommitCount: Self {
        .init(command: .git, arguments: ["rev-list", "--count", "HEAD"])
    }

    static var gitFetchAndPruneTags: Self {
        .init(command: .git, arguments: ["fetch", "--tags", "--prune-tags", "--prune"])
    }

    static var gitFirstCommitDate: Self {
        .init(command: .git, arguments: ["log", "--max-parents=0", "-n1", #"--format=format:"%ct""#.verbatim])
    }

    static var gitLastCommitDate: Self {
        .init(command: .git, arguments: ["log", "-n1", #"--format=format:"%ct""#.verbatim])
    }

    static func gitReset(hard: Bool) -> Self {
        hard
        ? .init(command: .git, arguments: ["reset", "--hard"])
        : .init(command: .git, arguments: ["reset"])
    }

    static func gitReset(to branch: String, hard: Bool) -> Self {
        hard
        ? .init(command: .git, arguments: ["reset", "origin/\(branch.quoted)".verbatim, "--hard"])
        : .init(command: .git, arguments: ["reset", "origin/\(branch.quoted)".verbatim])

    }

    static func gitRevisionInfo(reference: Reference, separator: String = "-") -> Self {
        .init(command: .env,
              arguments: [
                "GNUTLS_CPUID_OVERRIDE=0x1".verbatim,
                "git", "log", "-n1",
                #"--format=format:"%H\#(separator.quoted)%ct""#.verbatim,
                "\(reference)".quoted
              ])

    }

    static func gitShowDate(_ commit: CommitHash) -> Self {
        .init(command: .git, arguments: ["show", "-s", "--format=%ct", commit.quoted])
    }

    static var gitListTags: Self {
        .init(command: .git, arguments: ["tag"])
    }

    static var gitShortlog: Self {
        .init(command: .git, arguments: ["shortlog", "-sn", "HEAD"])
    }

}


//MARK: Other commands

extension ShellOutCommand {
    static var swiftDumpPackage: Self {
        .init(command: .swift, arguments: ["package", "dump-package"])
    }
}


extension SafeString {
    static let env = "env".unchecked
    static let git = "git".unchecked
    static let swift = "swift".unchecked
}
