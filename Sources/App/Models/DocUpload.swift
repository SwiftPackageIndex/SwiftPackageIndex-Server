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
import Vapor


final class DocUpload: Model, Content {
    static let schema = "doc_uploads"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    // periphery:ignore
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // reference fields

    @Parent(key: "build_id")
    var build: Build

    // data fields

    @Field(key: "error")
    var error: String?

    @Field(key: "file_count")
    var fileCount: Int?

    @Field(key: "linkable_paths_count")
    var linkablePathsCount: Int?

    @Field(key: "log_url")
    var logUrl: String?

    @Field(key: "mb_size")
    var mbSize: Int?

    @Field(key: "status")
    var status: Status

    init() { }

    init(
        id: Id? = nil,
        error: String? = nil,
        fileCount: Int? = nil,
        logUrl: String? = nil,
        mbSize: Int? = nil,
        status: Status
    ) {
        self.id = id
        self.error = error
        self.fileCount = fileCount
        self.logUrl = logUrl
        self.mbSize = mbSize
        self.status = status
    }
}


extension DocUpload {
    enum Status: String, Codable, CustomStringConvertible {
        case ok
        case failed
        case pending
        case skipped
        case uploading

        var description: String {
            switch self {
                case .ok: return "Successful"
                case .failed: return "Failed"
                case .pending: return "Pending"
                case .skipped: return "Skipped"
                case .uploading: return "Uploading"
            }
        }
    }
}


extension DocUpload {

    /// Attach a ``DocUpload`` to a ``Build``, ensuring the relationship is saved on both sides. This will save changes on the ``Build`` parameter as well.
    /// - Parameters:
    ///   - build: ``Build`` to attach
    ///   - database: ``Database`` to use for saving
    func attach(to build: Build, on database: Database) async throws {
        $build.id = try build.requireID()
        build.$docUpload.id = try requireID()
        try await database.transaction {
            try await self.save(on: $0)
            try await build.save(on: $0)
        }
    }

    /// Detach a ``DocUpload`` from its associated ``Build`` record and also delete it . Deletion by itself would fail, due to the foreign key constraint on the `builds` table.
    ///   - database: ``Database`` to use for deletion
    func detachAndDelete(on database: Database) async throws {
        try await database.transaction { tx in
            if self.$build.value == nil {
                try await self.$build.load(on: tx)
            }
            // We need to reset builds.doc_upload_id to nil to prevent the FK constraint from blocking the delete
            self.build.$docUpload.id = nil
            try await self.build.save(on: tx)
            try await self.delete(on: tx)
        }
    }

}
