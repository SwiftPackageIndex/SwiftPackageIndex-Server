import Fluent
import Vapor


extension API {
    
    struct BuildController {
        func create(req: Request) throws -> EventLoopFuture<Build> {
            let dto = try req.content.decode(PostCreateBuildDTO.self)
            return App.Version.find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMapThrowing { try Build(dto, $0) }
                .flatMap { build in
                    AppMetrics.buildReportTotal?.inc(1, .init(build.platform, build.swiftVersion))
                    return build.upsert(on: req.db).transform(to: build)
                }
        }
        
        func trigger(req: Request) throws -> EventLoopFuture<HTTPStatus> {
            guard let id = req.parameters.get("id"),
                  let versionId = UUID(uuidString: id) else {
                return req.eventLoop.future(error: Abort(.badRequest))
            }
            let dto = try req.content.decode(PostBuildTriggerDTO.self)
            return Build.trigger(database: req.db,
                                 client: req.client,
                                 platform: dto.platform,
                                 swiftVersion: dto.swiftVersion,
                                 versionId: versionId)
        }
    }
    
}
