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

import Dependencies
import DependenciesMacros
import Vapor
import SotoCognitoAuthenticationKit

@DependencyClient
struct CognitoClient {
    var authenticate: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse
    var authenticateToken: @Sendable (_ req: Request, _ sessionID: String, _ accessToken: String) async throws -> Void
    var signup: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void
    var resetPassword: @Sendable (_ req: Request, _ username: String, _ password: String, _ confirmationCode: String) async throws -> Void
    var forgotPassword: @Sendable (_ req: Request, _ username: String) async throws -> Void
    var confirmSignUp: @Sendable (_ req: Request, _ username: String, _ confirmationCode: String) async throws -> Void
    var deleteUser: @Sendable (_ req: Request) async throws -> Void
}

extension CognitoClient: DependencyKey {
    static var liveValue: CognitoClient {
        .init(
            authenticate: { req, username, password in try await Cognito.authenticate(req: req, username: username, password: password) },
            authenticateToken: { req, sessionID, accessToken in try await Cognito.authenticateToken(req: req, sessionID: sessionID, accessToken: accessToken)},
            signup : { req, username, password in try await Cognito.signup(req: req, username: username, password: password) },
            resetPassword : { req, username, password, confirmationCode in try await Cognito.resetPassword(req: req, username: username, password: password, confirmationCode: confirmationCode) },
            forgotPassword: { req, username in try await Cognito.forgotPassword(req: req, username: username) },
            confirmSignUp: { req, username, confirmationCode in try await Cognito.confirmSignUp(req: req, username: username, confirmationCode: confirmationCode) },
            deleteUser: { req in try await Cognito.deleteUser(req: req) }
        )
    }
}

extension CognitoClient: Sendable, TestDependencyKey {
    static var testValue: Self { Self() }
}

extension DependencyValues {
    var cognito: CognitoClient {
        get { self[CognitoClient.self] }
        set { self[CognitoClient.self] = newValue }
    }
}
    
