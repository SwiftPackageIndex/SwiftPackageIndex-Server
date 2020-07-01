import Vapor


struct User: Authenticatable {
    var name: String
    
    static var builder: Self { .init(name: "builder") }
    
    struct TokenAuthenticator: BearerAuthenticator {
        func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
            if
                let builderToken = Current.builderToken(),
                bearer.token == builderToken {
                request.auth.login(User.builder)
            }
            return request.eventLoop.makeSucceededFuture(())
        }
    }
}
