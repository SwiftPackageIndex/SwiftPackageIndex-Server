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

import Vapor


enum PackageCollectionController {
    @Sendable
    static func generate(req: Request) async throws -> SignedCollection {
        AppMetrics.packageCollectionGetTotal?.inc()

        guard let collectionType = getCollectionType(req: req) else {
            throw Abort(.notFound)
        }

        do {
            switch collectionType {
                case let .author(owner):
                    return try await SignedCollection.generate(
                        db: req.db,
                        filterBy: .author(owner),
                        authorName: "\(owner) via the Swift Package Index"
                    )
                case let .custom(name):
                    fatalError("FIXME")
            }
        } catch PackageCollection.Error.noResults {
            throw Abort(.notFound)
        }
    }

    enum CollectionType {
        case author(String)
        case custom(String)
    }

    static func getCollectionType(req: Request) -> CollectionType? {
        if let owner = req.parameters.get("owner") { return .author(owner) }
        if let name = req.parameters.get("name") { return .custom(name) }
        return nil
    }
}
