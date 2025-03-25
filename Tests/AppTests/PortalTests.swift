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

@testable import App

import Testing

import Fluent
import Vapor
import Dependencies
import SotoCognitoAuthenticationKit

extension AllTests.PortalTests {

    @Test func test_portal_route_protected() async throws {
        try await withApp { app in
            try await app.test(.GET, "portal", afterResponse: { res async throws in
                #expect(res.status == .seeOther)
                if let location = res.headers.first(name: .location) {
                    #expect("/login" == location)
                }
            })
        }
    }

    @Test func test_login_successful_redirect() async throws {
        try await withDependencies {
            let jsonData: Data = """
            {
                "authenticated": {
                    "accessToken": "",
                    "idToken": "",
                    "refreshToken": "",
                }
            }
            """.data(using: .utf8)!
            let decoder = JSONDecoder()
            let response = try decoder.decode(CognitoAuthenticateResponse.self, from: jsonData)
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in return response }
            $0.cognito.authenticate = mock
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "login", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword"])
                }, afterResponse: { res in
                    #expect(res.status == .seeOther)
                    if let location = res.headers.first(name: .location) {
                        #expect("/portal" == location)
                    }
                })
            }
        }
    }

    @Test func test_successful_login_secure_cookie_set() async throws {
        try await withDependencies {
            let jsonData: Data = """
            {
                "authenticated": {
                    "accessToken": "123",
                    "idToken": "",
                    "refreshToken": "",
                }
            }
            """.data(using: .utf8)!
            let decoder = JSONDecoder()
            let response = try decoder.decode(CognitoAuthenticateResponse.self, from: jsonData)
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in
                return response
            }
            $0.cognito.authenticate = mock
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "login", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword"])
                }, afterResponse: { res in
                    if let cookieHeader = res.headers.first(name: .setCookie) {
                        #expect(cookieHeader.contains("HttpOnly") == true)
                        #expect(cookieHeader.contains("Secure") == true)
                    }
                })
            }
        }
    }

    @Test func test_login_soto_error() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in
                throw SotoCognitoError.unauthorized(reason: "reason")
            }
            $0.cognito.authenticate = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "login", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword"])
                }, afterResponse: { res in
                    #expect(res.status == .unauthorized)
                })
            }
        }
    }

    @Test func test_login_some_aws_client_error() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in
                throw AWSClientError.accessDenied
            }
            $0.cognito.authenticate = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "login", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword"])
                }, afterResponse: { res in
                    #expect(res.status == .unauthorized)
                })
            }
        }
    }

    @Test func test_login_throw_other_error() async throws {
        struct SomeError: Error {}

        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in
                throw SomeError()
            }
            $0.cognito.authenticate = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "login", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword"])
                }, afterResponse: { res in
                    #expect(res.status == .unauthorized)
                })
            }
        }
    }

    @Test func test_signup_successful_view_change() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void = { _, _, _ in }
            $0.cognito.signup = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "signup", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword"])
                }, afterResponse: { res in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Verify") == true)
                })
            }
        }
    }

    @Test func test_signup_some_aws_error() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void = { _, _, _ in
                throw AWSClientError.accessDenied
            }
            $0.cognito.signup = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "signup", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword"])
                }, afterResponse: { res in
                    #expect(res.body.string.contains("There was an error") == true)
                })
            }
        }
    }

    @Test func test_signup_throw_some_error() async throws {
        struct SomeError: Error {}

        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void = { _, _, _ in
                throw SomeError()
            }
            $0.cognito.signup = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "signup") { res async throws in
                    #expect(res.body.string.contains("error") == true)
                }
            }
        }
    }

    @Test func test_reset_password_successful_view_change() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String, _ confirmationCode: String) async throws -> Void = { _, _, _, _ in }
            $0.cognito.resetPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "reset-password", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword", "confirmationCode": "123"])
                }, afterResponse: { res in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Successfully changed password") == true)
                })
            }
        }
    }

    @Test func test_reset_pass_throws_aws_error() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String, _ confirmationCode: String) async throws -> Void = { _, _, _, _ in
                throw AWSClientError.accessDenied
            }
            $0.cognito.resetPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "reset-password", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword", "confirmationCode": "123"])
                }, afterResponse: { res in
                    #expect(res.body.string.contains("There was an error") == true)
                })
            }
        }
    }

    @Test func test_reset_pass_throws_other_error() async throws {
        try await withDependencies {
            struct SomeError: Error {}
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String, _ confirmationCode: String) async throws -> Void = { _, _, _, _ in
                throw SomeError()
            }
            $0.cognito.resetPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "reset-password", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "password": "testpassword", "confirmationCode": "123"])
                }, afterResponse: { res in
                    #expect(res.body.string.contains("An unknown error occurred"))
                })
            }
        }
    }

    @Test func test_forgot_pass_successful_view_change() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String) async throws -> Void = { _, _ in }
            $0.cognito.forgotPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "forgot-password", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail"])
                }, afterResponse: { res in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Reset Password") == true)
                })
            }
        }
    }

    @Test func test_forgot_pass_throws() async throws {
        try await withDependencies {
            struct SomeError: Error {}
            let mock: @Sendable (_ req: Request, _ username: String) async throws -> Void = { _, _ in throw SomeError() }
            $0.cognito.forgotPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "forgot-password", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail"])
                }, afterResponse: { res in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("An error occurred") == true)
                })
            }
        }
    }

    @Test func test_logout_successful_redirect() async throws {
        try await withApp { app in
            try await app.test(.POST, "logout") { res async throws in
                #expect(res.status == .seeOther)
                if let location = res.headers.first(name: .location) {
                    #expect("/" == location)
                }
            }
        }
    }

    @Test func test_logout_session_destroyed() async throws {
        try await withApp { app in
            try await app.test(.POST, "logout") { res async throws in
                let cookie = res.headers.setCookie?["vapor-session"]
                #expect(cookie == nil)
            }
        }
    }

    @Test func test_verify_successful_view_Change() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ confirmationCode: String) async throws -> Void = { _, _, _ in }
            $0.cognito.confirmSignUp = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "verify", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "confirmationCode": "123"])
                }, afterResponse: { res in
                    #expect(res.status == .ok)
                    #expect(res.body.string.contains("Successfully confirmed signup") == true)
                })
            }
        }
    }

    @Test func test_verify_throws_aws_error() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ confirmationCode: String) async throws -> Void = { _, _, _ in
                throw AWSClientError.accessDenied
            }
            $0.cognito.confirmSignUp = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "verify", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "confirmationCode": "123"])
                }, afterResponse: { res in
                    #expect(res.body.string.contains("There was an error") == true)
                })
            }
        }
    }

    @Test func test_verify_throws_some_error() async throws {
        try await withDependencies {
            struct SomeError: Error {}
            let mock: @Sendable (_ req: Request, _ username: String, _ confirmationCode: String) async throws -> Void = { _, _, _ in
                throw SomeError()
            }
            $0.cognito.confirmSignUp = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "verify", beforeRequest: { req async throws in
                    try req.content.encode(["email": "testemail", "confirmationCode": "123"])
                }, afterResponse: { res in
                    #expect(res.body.string.contains("An unknown error occurred"))
                })
            }
        }
    }

    @Test func test_delete_successful_redirect() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request) async throws -> Void = { _ in }
            $0.cognito.deleteUser = mock
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "delete") {  res async throws in
                    #expect(res.status == .seeOther)
                    if let location = res.headers.first(name: .location) {
                        #expect("/" == location)
                    }
                }
            }
        }
    }

    @Test func test_delete_session_destroyed() async throws {
        try await withDependencies {
            let mock: @Sendable (_ req: Request) async throws -> Void = { _ in }
            $0.cognito.deleteUser = mock
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "delete") {  res async throws in
                    let cookie = res.headers.setCookie?["vapor-session"]
                    #expect(cookie == nil)
                }
            }
        }
    }

    @Test func test_delete_throws() async throws {
        try await withDependencies {
            struct SomeError: Error {}
            let mock: @Sendable (_ req: Request) async throws -> Void = { _ in throw SomeError() }
            $0.cognito.deleteUser = mock
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp { app in
                try await app.test(.POST, "delete") {  res async throws in
                    #expect(res.status == .internalServerError)
                    #expect(res.body.string.contains("An unknown error occurred"))
                }
            }
        }
    }
}
