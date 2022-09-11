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
    case invalidString
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
        let tags = try Current.shell.run(command: .gitListTags, at: path)
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
    
    static func shortlog(at path: String) throws -> String {
        guard let shortlog = try? Current.shell.run(command: .gitShortlog, at: path) else {
            throw GitError.invalidString
        }
        return shortlog
    }

    struct RevisionInfo: Equatable {
        let commit: CommitHash
        let date: Date
    }
}


