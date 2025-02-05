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
import DependenciesMacros
import IssueReporting


@DependencyClient
struct GitClient {
    var commitCount: @Sendable (_ at: String) async throws -> Int
    var firstCommitDate: @Sendable (_ at: String) async throws -> Date
    var getTags: @Sendable (_ at: String) async throws -> [Reference]
    var hasBranch: @Sendable (Reference, _ at: String) async throws -> Bool
    var lastCommitDate: @Sendable (_ at: String) async throws -> Date
    var revisionInfo: @Sendable (Reference, _ at: String) async throws -> Git.RevisionInfo
    var shortlog: @Sendable (_ at: String) async throws -> String
}


extension GitClient: DependencyKey {
    static var liveValue: Self {
        .init(
            commitCount: { path in try await Git.commitCount(at: path) },
            firstCommitDate: { path in try await Git.firstCommitDate(at: path) },
            getTags: { path in try await Git.getTags(at: path) },
            hasBranch: { ref, path in try await Git.hasBranch(ref, at: path) },
            lastCommitDate: { path in try await Git.lastCommitDate(at: path) },
            revisionInfo: { ref, path in try await Git.revisionInfo(ref, at: path) },
            shortlog: { path in try await Git.shortlog(at: path) }
        )
    }
}


extension GitClient: TestDependencyKey {
    static var testValue: Self { .init() }
}


extension DependencyValues {
    var git: GitClient {
        get { self[GitClient.self] }
        set { self[GitClient.self] = newValue }
    }
}
