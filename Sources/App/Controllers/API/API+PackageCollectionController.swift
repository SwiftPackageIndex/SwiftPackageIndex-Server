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
import PackageCollectionsModel
import PackageCollectionsSigning
import Vapor


extension API {

    enum PackageCollectionController {

        static func generate(req: Request) throws -> EventLoopFuture<SignedCollection> {
            AppMetrics.apiPackageCollectionGetTotal?.inc()

            let dto = try req.content.decode(PostPackageCollectionDTO.self)

            switch dto.selection {
                case let .author(author):
                    return SignedCollection.generate(
                        db: req.db,
                        filterBy: .author(author),
                        authorName: dto.authorName ?? "Swift Package Index",
                        collectionName: dto.collectionName ?? author,
                        keywords: dto.keywords,
                        overview: dto.overview,
                        revision: dto.revision
                    )
                case let .packageURLs(packageURLs):
                    // Then try if it's "packageURLs" based
                    guard packageURLs.count <= 20 else {
                        throw Abort(.badRequest)
                    }
                    return SignedCollection.generate(
                        db: req.db,
                        filterBy: .urls(packageURLs),
                        authorName: dto.authorName ?? "Swift Package Index",
                        collectionName: dto.collectionName ?? "Package List",
                        keywords: dto.keywords,
                        overview: dto.overview,
                        revision: dto.revision
                    )
            }
        }

    }

}


extension PackageCollectionSigning.Model.SignedCollection: Vapor.Content {}


extension API {
    struct PostPackageCollectionDTO: Codable {
        enum Selection: Codable {
            case author(String)
            case packageURLs([String])
        }

        var selection: Selection

        var authorName: String?
        var keywords: [String]?
        var collectionName: String?
        var overview: String?
        var revision: Int?
    }
}
