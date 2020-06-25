import Fluent
import Vapor


extension API {

    struct BuildController {
        func create(req: Request) throws -> EventLoopFuture<Build> {
            let dto = try req.content.decode(Build.PostCreateDTO.self)
            return App.Version.find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMapThrowing { try Build(dto, $0) }
                .flatMap { build in build.save(on: req.db).transform(to: build) }
        }

        func trigger(req: Request) throws -> EventLoopFuture<HTTPStatus> {
            let dto = try req.content.decode(Build.PostTriggerDTO.self)
            return App.Version.find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))
                // FIXME: look up parameters and post Gitlab build trigger
                .transform(to: .ok)
        }
    }

}
