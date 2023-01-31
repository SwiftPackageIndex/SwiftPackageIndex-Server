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

    @Field(key: "log_group")
    var logGroup: String?

    @Field(key: "log_region")
    var logRegion: String?

    @Field(key: "log_stream")
    var logStream: String?

    @Field(key: "mb_size")
    var mbSize: Int?

    @Field(key: "status")
    var status: Status

    // FIXME: implement
    var logUrl: String? {
        // const link = `https://${process.env.AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${process.env.AWS_REGION}#logsV2:log-groups/log-group/${process.env.AWS_LAMBDA_LOG_GROUP_NAME.replace(/\//g, '$252F')}/log-events/${process.env.AWS_LAMBDA_LOG_STREAM_NAME.replace('$', '$2524').replace('[', '$255B').replace(']', '$255D').replace(/\//g, '$252F')}`
        nil
    }

    init() { }

    init(
        id: Id? = nil,
        buildId: Build.Id,
        versionId: Version.Id,
        error: String? = nil,
        fileCount: Int? = nil,
        logGroup: String? = nil,
        logRegion: String? = nil,
        logStream: String? = nil,
        mbSize: Int? = nil,
        status: Status
    ) {
        self.id = id
        self.$build.id = buildId
        self.$version.id = versionId
        self.error = error
        self.fileCount = fileCount
        self.logGroup = logGroup
        self.logRegion = logRegion
        self.logStream = logStream
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
