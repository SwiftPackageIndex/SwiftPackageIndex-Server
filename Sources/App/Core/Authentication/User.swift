// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Authentication
import Dependencies
import JWTKit
import Vapor


struct User: Authenticatable, Equatable {
    var name: String

    /// A user's identifier provides additional detail in cases where multiple clients refer to the same user entity via different authentication mechanisms. For example, API access via bearer tokens creates a user named `api` and the additional identifier allows to uniquely identify which bearer token authenticated the user.
    var identifier: String
}


extension User {
    static func api(for token: String) -> Self {
        .init(name: "api", identifier: String(token.sha256Checksum.prefix(8)))
    }

    struct APITierAuthenticator: AsyncBearerAuthenticator {
        var tier: Tier<V1>

        @Dependency(\.environment) var environment
        @Dependency(\.logger) var logger

        func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
            guard let signingKey = environment.apiSigningKey() else { throw AppError.envVariableNotSet("API_SIGNING_KEY") }
            let signer = Signer(secretSigningKey: signingKey)
            do {
                let key = try signer.verifyToken(bearer.token)
                guard key.isAuthorized(for: tier) else { throw Abort(.unauthorized) }
                request.auth.login(User.api(for: bearer.token))
            } catch let error as JWTError {
                logger.warning("\(error)")
                throw Abort(.unauthorized)
            }
        }
    }
}


extension User {
    static var builder: Self { .init(name: "builder", identifier: "builder") }

    struct BuilderAuthenticator: AsyncBearerAuthenticator {
        @Dependency(\.environment) var environment

        func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
            if let token = environment.builderToken(), bearer.token == token {
                request.auth.login(User.builder)
            }
        }
    }
}
