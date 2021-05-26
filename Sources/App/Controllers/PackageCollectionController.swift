import Vapor


struct PackageCollectionController {
    func generate(req: Request) throws -> EventLoopFuture<PackageCollection> {
        guard let owner = req.parameters.get("owner") else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return PackageCollection.generate(
            db: req.db,
            owner: owner,
            authorName: "\(owner) via Swift Package Index",
            collectionName: "\(owner) package collection"
        )
    }
}
