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

import Dependencies
import SemanticVersion
import ShellOut


enum Git {

    enum Error: LocalizedError {
        case invalidInteger
        case invalidTimestamp
        case invalidRevisionInfo(String)
    }

    static func commitCount(at path: String) async throws -> Int {
        @Dependency(\.shell) var shell
        let res = try await shell.run(command: .gitCommitCount, at: path)
        guard let count = Int(res) else {
            throw Error.invalidInteger
        }
        return count
    }

    static func firstCommitDate(at path: String) async throws -> Date {
        @Dependency(\.shell) var shell
        let res = String(
            try await shell.run(command: .gitFirstCommitDate, at: path)
                .trimming { $0 == Character("\"") }
        )
        guard let timestamp = TimeInterval(res) else {
            throw Error.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func lastCommitDate(at path: String) async throws -> Date {
        @Dependency(\.shell) var shell
        let res = String(
            try await shell.run(command: .gitLastCommitDate, at: path)
                .trimming { $0 == Character("\"") }
        )
        guard let timestamp = TimeInterval(res) else {
            throw Error.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func getTags(at path: String) async throws -> [Reference] {
        @Dependency(\.shell) var shell
        let tags = try await shell.run(command: .gitListTags, at: path)
        return tags.split(separator: "\n")
            .map(String.init)
            .compactMap { tag in SemanticVersion(tag).map { ($0, tag) } }
            .map { Reference.tag($0, $1) }
    }

    static func hasBranch(_ reference: Reference, at path: String) async throws -> Bool {
        @Dependency(\.shell) var shell
        guard let branchName = reference.branchName else { return false }
        do {
            _ = try await shell.run(command: .gitHasBranch(branchName), at: path)
            return true
        } catch {
            return false
        }
    }

    static func revisionInfo(_ reference: Reference, at path: String) async throws -> RevisionInfo {
        @Dependency(\.shell) var shell
        @Dependency(\.logger) var logger
        let separator = "-"
        let res = String(
            try await shell.run(command: .gitRevisionInfo(reference: reference, separator: separator),
                                        at: path)
                .trimming { $0 == Character("\"") }
        )
        let parts = res.components(separatedBy: separator)
        guard parts.count == 2 else {
            logger.warning(#"Git.invalidRevisionInfo: \#(res) for '\#(ShellOutCommand.gitRevisionInfo(reference: reference, separator: separator))' at: \#(path)"#)
            throw Error.invalidRevisionInfo(res)
        }
        let hash = parts[0]
        guard let timestamp = TimeInterval(parts[1]) else { throw Error.invalidTimestamp }
        let date = Date(timeIntervalSince1970: timestamp)
        return .init(commit: hash, date: date)
    }

    static func shortlog(at path: String) async throws -> String {
        @Dependency(\.shell) var shell
        return try await shell.run(command: .gitShortlog, at: path)
    }

    struct RevisionInfo: Equatable {
        let commit: CommitHash
        let date: Date
    }

}
