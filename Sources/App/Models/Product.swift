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


final class Product: Model, Content {
    static let schema = "products"

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

    @Parent(key: "version_id")
    var version: Version

    // data fields

    @Field(key: "type")
    var type: ProductType?

    @Field(key: "name")
    var name: String

    @Field(key: "targets")
    var targets: [String]

    init() {}

    init(id: Id? = nil,
         version: Version,
         type: ProductType,
         name: String,
         targets: [String] = []) throws {
        self.id = id
        self.$version.id = try version.requireID()
        self.type = type
        self.name = name
        self.targets = targets
    }
}


enum ProductType: Codable, Equatable {
    case executable
    case library(LibraryType)
    case plugin
    case test

    init(manifestProductType: Manifest.ProductType) {
        switch manifestProductType {
            case .executable:
                self = .executable
            case .library(.automatic):
                self = .library(.automatic)
            case .library(.dynamic):
                self = .library(.dynamic)
            case .library(.static):
                self = .library(.static)
            case .plugin:
                self = .plugin
            case .test:
                self = .test
        }
    }

    enum LibraryType: String, Codable {
        case automatic
        case `dynamic`
        case `static`
    }

    var isLibrary: Bool {
        switch self {
            case .library: return true
            case .executable, .plugin, .test: return false
        }
    }

    var isExecutable: Bool {
        switch self {
            case .executable: return true
            case .library, .plugin, .test: return false
        }
    }

    var isPlugin: Bool {
        switch self {
            case .plugin: return true
            default: return false
        }
    }
}


extension Product: Equatable {
    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }
}


// PostgresKit.PostgresJSONBCodable is a workaround for https://github.com/vapor/postgres-kit/issues/207
import PostgresKit
extension ProductType: PostgresJSONBCodable { }
