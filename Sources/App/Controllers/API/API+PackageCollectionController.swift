// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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


extension API {

    enum PackageCollectionController {

        static func generate(req: Request) throws -> EventLoopFuture<SignedCollection> {
            AppMetrics.apiPackageCollectionGetTotal?.inc()

            // First try decoding "owner" type DTO
            if let dto = try? req.content.decode(PostPackageCollectionOwnerDTO.self) {
                return SignedCollection.generate(
                    db: req.db,
                    filterBy: .author(dto.owner),
                    authorName: dto.authorName ?? "Swift Package Index",
                    collectionName: dto.collectionName ?? dto.owner,
                    keywords: dto.keywords,
                    overview: dto.overview,
                    revision: dto.revision
                )
            }

            // Then try if it's "packageURLs" based
            let dto = try req.content.decode(PostPackageCollectionPackageUrlsDTO.self)
            guard dto.packageUrls.count <= 20 else {
                throw Abort(.badRequest)
            }
            return SignedCollection.generate(
                db: req.db,
                filterBy: .urls(dto.packageUrls),
                authorName: dto.authorName ?? "Swift Package Index",
                collectionName: dto.collectionName ?? "Package List",
                keywords: dto.keywords,
                overview: dto.overview,
                revision: dto.revision
            )
        }

    }

}


extension SignedCollection: Content {}


extension API {

    struct PostPackageCollectionOwnerDTO: Codable {
        var owner: String

        var authorName: String?
        var keywords: [String]?
        var collectionName: String?
        var overview: String?
        var revision: Int?
    }

    struct PostPackageCollectionPackageUrlsDTO: Codable {
        var packageUrls: [String]

        var authorName: String?
        var keywords: [String]?
        var collectionName: String?
        var overview: String?
        var revision: Int?
    }

}
