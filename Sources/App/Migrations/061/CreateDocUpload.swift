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


struct CreateDocUpload: AsyncMigration {
    let versionIdDocUploadIdConstraint = "uq:builds.version_id+builds.doc_upload_id"
    let docUploadIdConstraint = "uq:builds.doc_upload_id"

    func prepare(on database: Database) async throws {
        do {  // create doc_uploads table
            try await database.schema("doc_uploads")

            // managed fields
                .id()
                .field("created_at", .datetime)
                .field("updated_at", .datetime)

            // reference fields
                .field("build_id", .uuid,
                       .references("builds", "id", onDelete: .cascade), .required)

            // data fields
                .field("error", .string)
                .field("file_count", .int)
                .field("log_url", .string)
                .field("mb_size", .int)
                .field("status", .string, .required)

                .create()
        }
        do {  // add reference field to builds table
            try await database.schema("builds")
                  .field("doc_upload_id", .uuid, .references("doc_uploads", "id"))
                  .unique(on: "version_id", "doc_upload_id",
                          name: versionIdDocUploadIdConstraint)
                  .unique(on: "doc_upload_id", name: docUploadIdConstraint)
                  .update()
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema("builds")
            .deleteConstraint(name: docUploadIdConstraint)
            .deleteConstraint(name: versionIdDocUploadIdConstraint)
            .update()

        try await database.schema("builds")
            .deleteField("doc_upload_id")
            .update()
        try await database.schema("doc_uploads").delete()
    }
}
