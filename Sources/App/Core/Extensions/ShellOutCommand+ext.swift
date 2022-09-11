// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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
        .init(string: "git clean -fdx")
    }

    static var gitCommitCount: Self {
        .init(string: "git rev-list --count HEAD")
    }

    static var gitFetchAndPruneTags: Self {
        .init(string: "git fetch --tags --prune-tags --prune")
    }

    static var gitFirstCommitDate: Self {
        .init(string: #"git log --max-parents=0 -n1 --format=format:"%ct""#)
    }

    static var gitLastCommitDate: Self {
        .init(string: #"git log -n1 --format=format:"%ct""#)
    }

    static func gitReset(hard: Bool) -> Self {
        .init(string: "git reset\(hard ? " --hard" : "")")
    }

    static func gitReset(to branch: String, hard: Bool) -> Self {
        .init(string: #"git reset "origin/\#(branch)"\#(hard ? " --hard" : "")"#)
    }

    static func gitRevisionInfo(reference: Reference, separator: String = "-") -> Self {
        let safe = sanitizeInput("\(reference)")
        return .init(string: #"git log -n1 --format=format:"%H\#(separator)%ct" "\#(safe)""#)
    }

    static func gitShowDate(_ commit: CommitHash) -> Self {
        let safe = sanitizeInput("\(commit)")
        return .init(string: #"git show -s --format=%ct "\#(safe)""#)
    }

    static var gitListTags: Self {
        .init(string: "git tag")
    }
    
    static var gitShortlog: Self {
        .init(string: "git shortlog -sne")
    }

}


//MARK: Other commands

extension ShellOutCommand {
    static var swiftDumpPackage: Self {
        .init(string: "swift package dump-package")
    }
}


// MARK: Helper

extension ShellOutCommand {

    /// Sanitize input strings not controlled by us. Ensure commands that use input strings
    /// properly quote the commands:
    ///   let safe = sanitizeInput(input)
    /// and then use the result in quoted commands only:
    ///   Current.shell.run(#"ls -l "\(safe)""#)
    /// - Parameter input: user input string
    /// - Returns: sanitized string
    static func sanitizeInput(_ input: String) -> String {
        let bannedCharacters = CharacterSet.init(charactersIn: "\"\\")
            .union(CharacterSet.newlines)
            .union(CharacterSet.decomposables)
            .union(CharacterSet.illegalCharacters)
        return String(input.unicodeScalars.filter { !bannedCharacters.contains($0) })
    }

}
