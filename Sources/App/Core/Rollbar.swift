// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor


enum Rollbar {
    static func createItem(client: Client,
                           level: Item.Level,
                           message: String,
                           environment: Environment = (try? Environment.detect()) ?? .testing) async throws {
        guard let token = Current.rollbarToken() else {
            // fail silently
            return
        }
        _ = try await client.post(rollbarURI) { req in
            try req.content.encode(
                Rollbar.Item(accessToken: token,
                             environment: environment,
                             level: level,
                             message: message)
            )
        }
    }
    
    static var rollbarURI: URI { URI("https://api.rollbar.com/api/1/item/") }
}


extension Rollbar {
    struct Item: Content {
        // periphery:ignore
        let accessToken: String
        // periphery:ignore
        let data: Data
        
        // periphery:ignore
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
                // periphery:ignore
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
