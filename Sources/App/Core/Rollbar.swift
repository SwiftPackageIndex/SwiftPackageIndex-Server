import Vapor


enum Rollbar {
    static func createItem(client: Client,
                           level: Item.Level,
                           message: String,
                           environment: Environment = (try? Environment.detect()) ?? .testing) -> EventLoopFuture<Void> {
        guard let token = Current.rollbarToken() else {
            return client.eventLoop.makeFailedFuture(AppError.envVariableNotSet("ROLLBAR_TOKEN"))
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
            let environment: String
            let body: Body
            let level: Level
            let language = "swift"
            let framework = "vapor"
            let uuid = UUID().uuidString

            struct Body: Content {
                let message: Message

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
        }
    }
}
