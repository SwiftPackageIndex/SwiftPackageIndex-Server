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

import Fluent
import SQLKit
import Vapor


extension API.PackageController {
    enum History {
        struct Record: Codable, Equatable {
            var url: String
            var defaultBranch: String?
            var firstCommitDate: Date?
            var commitCount: Int
            var releaseCount: Int

            enum CodingKeys: String, CodingKey {
                case url
                case defaultBranch = "default_branch"
                case firstCommitDate = "first_commit_date"
                case commitCount = "commit_count"
                case releaseCount = "release_count"
            }

            func historyModel() -> GetRoute.Model.History? {
                guard let defaultBranch = defaultBranch,
                      let firstCommitDate = firstCommitDate else {
                    return nil
                }
                let cl = Link(
                    label: commitCount.labeled("commit"),
                    url: url.droppingGitExtension + "/commits/\(defaultBranch)")
                let rl = Link(
                    label: releaseCount.labeled("release"),
                    url: url.droppingGitExtension + "/releases")
                return .init(since: "\(inWords: Current.date().timeIntervalSince(firstCommitDate))",
                             commitCount: cl,
                             releaseCount: rl)
            }
        }

        static func query(on database: Database, owner: String, repository: String) async throws -> Record? {
            guard let db = database as? SQLDatabase else {
                fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
            }
            // This query cannot expressed in Fluent, because it doesn't support
            // GROUP BY clauses.
            return try await db.raw(#"""
                    SELECT p.url, r.default_branch, r.first_commit_date, r.commit_count, count(v.reference) AS "release_count"
                    FROM packages p
                    JOIN repositories r ON r.package_id = p.id
                    LEFT JOIN versions v ON v.package_id = p.id
                        AND v.reference->'tag' IS NOT NULL
                        AND v.reference->'tag'->'semVer'->>'build' = ''
                        AND v.reference->'tag'->'semVer'->>'preRelease' = ''
                    WHERE r.owner ILIKE \#(bind: owner)
                    AND r.name ILIKE \#(bind: repository)
                    GROUP BY p.url, r.default_branch, r.first_commit_date, r.commit_count
                    """#)
            .first(decoding: Record.self)
        }
    }
}
