import Fluent
import Vapor


extension API {
    struct SearchController {
        static func get(req: Request) throws -> EventLoopFuture<[SearchResult]> {
            return req.eventLoop.future([
                .init(packageName: "FooBar", repositoryID: "someone/FooBar", summary: "A foo bar repo"),
                .init(packageName: "BazBaq", repositoryID: "another/barbaq", summary: "Some other repo"),
            ])
        }

    }

    struct SearchResult: Content, Equatable {
        let packageName: String
        let repositoryID: String
        let summary: String
    }
}
