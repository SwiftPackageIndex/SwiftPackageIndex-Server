import Fluent
import Vapor


extension API {

    struct PackageCollectionController {

        func get(req: Request) throws -> EventLoopFuture<PackageCollection> {
            guard let owner = req.query[String.self, at: "owner"]
            else {
                return req.eventLoop.future(error: Abort(.notFound))
            }

            return PackageCollection.generate(
                db: req.db,
                name: owner,
                overview: nil,
                keywords: nil,
                owner: owner,
                generatedBy: .init(name: "Swift Package Index"))
        }

    }

}


extension PackageCollection: Content {}
