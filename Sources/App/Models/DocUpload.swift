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

    @Parent(key: "version_id")
    var version: Version

    // data fields

    @Field(key: "error")
    var error: String?

    @Field(key: "file_count")
    var fileCount: Int?

    @Field(key: "log_url")
    var logUrl: String?

    @Field(key: "mb_size")
    var mbSize: Int?

    @Field(key: "status")
    var status: Status

    init() { }

    init(
        id: Id? = nil,
        buildId: Build.Id,
        versionId: Version.Id,
        error: String? = nil,
        fileCount: Int? = nil,
        logUrl: String? = nil,
        mbSize: Int? = nil,
        status: Status
    ) {
        self.id = id
        self.$build.id = buildId
        self.$version.id = versionId
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

        var description: String {
            switch self {
                case .ok: return "Successful"
                case .failed: return "Failed"
            }
        }
    }
}
