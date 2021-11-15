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
import SemanticVersion
import ShellOut


enum GitError: LocalizedError {
    case invalidInteger
    case invalidTimestamp
    case invalidRevisionInfo
}

extension Git {
    
    static func commitCount(at path: String) throws -> Int {
        let res = try Current.shell.run(command: .gitCommitCount, at: path)
        guard let count = Int(res) else {
            throw GitError.invalidInteger
        }
        return count
    }
    
    static func firstCommitDate(at path: String) throws -> Date {
        let res = try Current.shell.run(command: .gitFirstCommitDate, at: path)
        guard let timestamp = TimeInterval(res) else {
            throw GitError.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    static func lastCommitDate(at path: String) throws -> Date {
        let res = try Current.shell.run(command: .gitLastCommitDate, at: path)
        guard let timestamp = TimeInterval(res) else {
            throw GitError.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    static func getTags(at path: String) throws -> [Reference] {
        let tags = try Current.shell.run(command: .gitTag, at: path)
        return tags.split(separator: "\n")
            .map(String.init)
            .compactMap { tag in SemanticVersion(tag).map { ($0, tag) } }
            .map { Reference.tag($0, $1) }
    }
    
    static func showDate(_ commit: CommitHash, at path: String) throws -> Date {
        let res = try Current.shell.run(command: .gitShowDate(commit), at: path)
        guard let timestamp = TimeInterval(res) else {
            throw GitError.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    static func revisionInfo(_ reference: Reference, at path: String) throws -> RevisionInfo {
        let separator = "-"
        let res = try Current.shell.run(command: .gitRevisionInfo(reference: reference,
                                                                  separator: separator), at: path)
        let parts = res.components(separatedBy: separator)
        guard parts.count == 2 else { throw GitError.invalidRevisionInfo }
        let hash = parts[0]
        guard let timestamp = TimeInterval(parts[1]) else { throw GitError.invalidTimestamp }
        let date = Date(timeIntervalSince1970: timestamp)
        return .init(commit: hash, date: date)
    }
    
    
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
    
    struct RevisionInfo: Equatable {
        let commit: CommitHash
        let date: Date
    }
}


extension ShellOutCommand {

    static var gitClean: Self {
        .init(string: "git clean -fdx")
    }

    static var gitCommitCount: Self {
        .init(string: "git rev-list --count HEAD")
    }

    static var gitFetch: Self {
        .init(string: "git fetch --tags")
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

    static func gitRevisionInfo(reference: Reference, separator: String) -> Self {
        let safe = Git.sanitizeInput("\(reference)")
        return .init(string: #"git log -n1 --format=format:"%H\#(separator)%ct" "\#(safe)""#)
    }

    static func gitShowDate(_ commit: CommitHash) -> Self {
        let safe = Git.sanitizeInput("\(commit)")
        return .init(string: #"git show -s --format=%ct "\#(safe)""#)
    }

    static var gitTag: Self {
        .init(string: "git tag")
    }

}
