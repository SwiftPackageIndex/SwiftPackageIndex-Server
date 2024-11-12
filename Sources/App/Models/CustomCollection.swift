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

    @Field(key: "key")
    var key: String

    @Field(key: "name")
    var name: String

    @Field(key: "description")
    var description: String?

    @Field(key: "badge")
    var badge: String?

    @Field(key: "url")
    var url: URL

    // relationships

    @Siblings(through: CustomCollectionPackage.self, from: \.$customCollection, to: \.$package)
    var packages: [Package]

    init() { }

    init(id: Id? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, _ details: Details) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.key = details.key
        self.name = details.name
        self.description = details.description
        self.badge = details.badge
        self.url = details.url
    }
}


extension CustomCollection {
    struct Details: Codable, Equatable {
        var key: String
        var name: String
        var description: String?
        var badge: String?
        var url: URL
    }

    static func findOrCreate(on database: Database, _ details: Details) async throws -> CustomCollection {
        if let collection = try await CustomCollection.query(on: database)
            .filter(\.$key == details.key)
            .first() {
            if collection.details != details {
                // Update the collection if any of the details have changed
                collection.details = details
                try await collection.update(on: database)
            }
            return collection
        } else {
            let collection = CustomCollection(details)
            try await collection.save(on: database)
            return collection
        }
    }

    func reconcile(on database: Database, packageURLs: some Collection<URL>) async throws {
        let incoming: [Package.Id: Package] = .init(
            packages: try await Package.query(on: database)
                .filter(by: packageURLs)
                .all()
        )
        try await $packages.load(on: database)
        let existing: [Package.Id: Package] = .init(packages: packages)
        let newIDs = Set(incoming.keys).subtracting(Set(existing.keys))
        try await $packages.attach(incoming[newIDs], on: database)
        let removedIDs = Set(existing.keys).subtracting(Set(incoming.keys))
        try await $packages.detach(existing[removedIDs], on: database)
    }

    var details: Details {
        get {
            .init(key: key,
                  name: name,
                  description: description,
                  badge: badge,
                  url: url)
        }
        set {
            key = newValue.key
            name = newValue.name
            description = newValue.description
            badge = newValue.badge
            url = newValue.url
        }
    }
}


private extension [Package.Id: Package] {
    init(packages: [Package]) {
        self.init(
            packages.compactMap({ pkg in pkg.id.map({ ($0, pkg) }) }),
            uniquingKeysWith: { (first, second) in first }
        )
    }

    subscript(ids: some Collection<Package.Id>) -> [Package] {
        Array(ids.compactMap { self[$0] })
    }
}
