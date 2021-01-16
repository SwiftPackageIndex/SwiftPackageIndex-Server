import Fluent
import Vapor


extension API {

    struct PackageCollectionController {

        func generate(req: Request) throws -> EventLoopFuture<PackageCollection> {
            // First try decoding "owner" type DTO
            if let dto = try? req.content.decode(PostPackageCollectionOwnerDTO.self) {
                return PackageCollection.generate(
                    db: req.db,
                    owner: dto.owner,
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
            return PackageCollection.generate(
                db: req.db,
                packageURLs: dto.packageUrls,
                authorName: dto.authorName ?? "Swift Package Index",
                collectionName: dto.collectionName ?? "Package List",
                keywords: dto.keywords,
                overview: dto.overview,
                revision: dto.revision
            )
        }

    }

}


extension PackageCollection: Content {}


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
