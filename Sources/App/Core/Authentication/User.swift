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
import Vapor
import VaporToOpenAPI


struct User: Authenticatable, Equatable {
    var name: String

    /// A user's identifier provides additional detail in cases where multiple clients refer to the same user entity via different authentication mechanisms. For example, API access via bearer tokens creates a user named `api` and the additional identifier allows to uniquely identify which bearer token authenticated the user.
    var identifier: String
}


extension User {
    static func api(for token: String) -> Self {
        .init(name: "api", identifier: String(token.sha256Checksum.prefix(8)))
    }

    struct APIAuthenticator: AsyncBearerAuthenticator {
        func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
            if Current.isValidAPIToken(bearer.token) {
                request.auth.login(User.api(for: bearer.token))
            }
        }
    }

    struct APITierAuthenticator: AsyncBearerAuthenticator {
        var tier: Tier<V1>

        func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
            let signer = Signer(secretSigningKey: "")
            let key = try signer.verifyToken(bearer.token)
            guard key.isAuthorized(for: tier) else { throw Abort(.forbidden) }
            request.auth.login(User.api(for: bearer.token))
        }
    }
}


extension User {
    static var builder: Self { .init(name: "builder", identifier: "builder") }

    struct BuilderAuthenticator: AsyncBearerAuthenticator {
        func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
            if let builderToken = Current.builderToken(),
               bearer.token == builderToken {
                request.auth.login(User.builder)
            }
        }
    }
}


extension AuthSchemeObject {
    static var apiBearerToken: Self {
        .bearer(id: "api_token",
               description: "Token used for API access.")
    }
    static var builderBearerToken: Self {
        .bearer(id: "builder_token",
               description: "Token used for build result reporting.")
    }
}
