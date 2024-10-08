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


final class CustomCollection: @unchecked Sendable, Model, Content {
    static let schema = "custom_collections"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    // periphery:ignore
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // data fields

    @Field(key: "name")
    var name: String

    @Field(key: "description")
    var description: String?

    @Field(key: "badge")
    var badge: String?

    @Field(key: "url")
    var url: String

    init() { }

    init(id: Id? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, name: String, description: String? = nil, badge: String? = nil, url: String) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.description = description
        self.badge = badge
        self.url = url
    }

}
