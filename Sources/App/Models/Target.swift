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


final class Target: Model, Content {
    static let schema = "targets"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // reference fields

    @Parent(key: "version_id")
    var version: Version

    // data fields

    @Field(key: "name")
    var name: String

    // initializers

    init() { }

    init(id: UUID? = nil,
         version: Version,
         name: String) throws {
        self.id = id
        self.$version.id = try version.requireID()
        self.name = name
    }
}
