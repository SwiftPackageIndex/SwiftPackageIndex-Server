import Fluent
import Vapor


extension API {
    
    struct BuildController {
        func create(req: Request) throws -> EventLoopFuture<Build> {
            let dto = try req.content.decode(Build.PostCreateDTO.self)
            return App.Version.find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMapThrowing { try Build(dto, $0) }
                .flatMap { build in build.upsert(on: req.db).transform(to: build) }
        }
        
        func trigger(req: Request) throws -> EventLoopFuture<HTTPStatus> {
            guard let id = req.parameters.get("id"),
                  let versionId = UUID(uuidString: id) else {
                return req.eventLoop.future(error: Abort(.badRequest))
            }
            let dto = try req.content.decode(Build.PostTriggerDTO.self)
            return Build.trigger(database: req.db,
                                 client: req.client,
                                 versionId: versionId,
                                 platform: dto.platform,
                                 swiftVersion: dto.swiftVersion)
        }
    }
    
}
