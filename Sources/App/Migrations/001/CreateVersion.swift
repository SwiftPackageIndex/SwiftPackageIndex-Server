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

struct CreateVersion: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions")
            // managed fields
            .id()
            .field("created_at", .datetime)
            .field("updated_at", .datetime)

            // reference fields
            .field("package_id", .uuid,
                   .references("packages", "id", onDelete: .cascade))

            // data fields
            .field("commit", .string)
            .field("commit_date", .datetime)
            .field("package_name", .string)
            .field("reference", .json)
            .field("supported_platforms", .array(of: .json), .sql(.default("{}")))
            .field("swift_versions", .array(of: .json), .sql(.default("{}")))

            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("versions").delete()
    }
}
