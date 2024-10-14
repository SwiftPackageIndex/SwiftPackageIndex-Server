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


final class CustomCollectionPackage: @unchecked Sendable, Model, Content {
    static let schema = "custom_collections+packages"

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

    @Parent(key: "custom_collection_id")
    var customCollection: CustomCollection

    @Parent(key: "package_id")
    var package: Package

    init() { }

    init(id: Id? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, customCollection: CustomCollection, package: Package) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.customCollection = customCollection
        self.package = package
    }
}
