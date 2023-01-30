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

struct CreateRepository: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories")
            // managed fields
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)

            // reference fields
            .field("forked_from_id", .uuid,
                   .references("repositories", "id")).unique(on: "forked_from_id")
            .field("package_id", .uuid,
                   .references("packages", "id", onDelete: .cascade)).unique(on: "package_id")

            // data fields
            .field("authors", .array(of: .json), .sql(.default("{}")))
            .field("commit_count", .int)
            .field("default_branch", .string)
            .field("first_commit_date", .datetime)
            .field("forks", .int)
            .field("last_commit_date", .datetime)
            .field("last_issue_closed_at", .datetime)
            .field("last_pull_request_closed_at", .datetime)
            .field("license", .string)
            .field("name", .string)
            .field("open_issues", .int)
            .field("open_pull_requests", .int)
            .field("owner", .string)
            .field("stars", .int)
            .field("summary", .string)

            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("repositories").delete()
    }
}
