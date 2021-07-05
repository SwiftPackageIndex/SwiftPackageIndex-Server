import Vapor


struct PackageCollectionController {
    func generate(req: Request) throws -> EventLoopFuture<PackageCollection> {
        guard let owner = req.parameters.get("owner") else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return PackageCollection.generate(
            db: req.db,
            filterBy: .author(owner),
            authorName: "\(owner) via the Swift Package Index"
        ).flatMapError {
            if case PackageCollection.Error.noResults = $0 {
                return req.eventLoop.makeFailedFuture(Abort(.notFound))
            }
            return req.eventLoop.makeFailedFuture($0)
        }
    }
}
