import Vapor


enum Rollbar {
    static func createItem(client: Client,
                           level: Item.Level,
                           message: String,
                           environment: Environment = (try? Environment.detect()) ?? .testing) -> EventLoopFuture<Void> {
        guard let token = Current.rollbarToken() else {
            // fail silently
            return client.eventLoop.future()
        }
        return client.post(rollbarURI) { req in
            try req.content.encode(
                Rollbar.Item(accessToken: token,
                             environment: environment,
                             level: level,
                             message: message)
            )
        }
        .transform(to: ())
    }
    
    static var rollbarURI: URI { URI("https://api.rollbar.com/api/1/item/") }
}


extension Rollbar {
    struct Item: Content {
        let accessToken: String
        let data: Data
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case data
        }
        
        init(accessToken: String, environment: Environment, level: Level, message: String) {
            #if DEBUG
            // always pin to testing for debug builds, so we don't ever risk polluting prod
            let env = Environment.testing
            #else
            let env = environment
            #endif
            self.accessToken = accessToken
            self.data = .init(environment: env.name,
                              body: .init(message: message),
                              level: level)
        }
        
        struct Data: Content {
            var environment: String
            var body: Body
            var level: Level
            var language = "swift"
            var framework = "vapor"
            var uuid = UUID().uuidString
            
            struct Body: Content {
                var message: Message
                
                init(message: String) {
                    self.message = .init(body: message)
                }
                
                struct Message: Content {
                    let body: String
                }
            }
        }
        
        enum Level: String, Codable {
            case critical
            case error
            case warning
            case info
            case debug
            
            init(level: AppError.Level) {
                switch level {
                    case .critical: self = .critical
                    case .error:    self = .error
                    case .warning:  self = .warning
                    case .info:     self = .info
                    case .debug:    self = .debug
                }
            }
        }
    }
}
