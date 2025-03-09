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

import XCTest
import Fluent
import Vapor
import Dependencies
import SotoCognitoAuthenticationKit




class PortalTests: AppTestCase {

    func test_portal_route_protected() throws {
        try app.test(.GET, "portal") { res in
            XCTAssertEqual(res.status, .seeOther)
            if let location = res.headers.first(name: .location) {
                XCTAssertEqual("/login", location)
            }
        }
    }
    
    func test_login_successful_redirect() throws {
        try withDependencies {
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
            try app.test(.POST, "login", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .seeOther)
                if let location = res.headers.first(name: .location) {
                    XCTAssertEqual("/portal", location)
                }
            })
        }
    }
    
    func test_successful_login_secure_cookie_set() throws {
        try withDependencies {
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
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in return response }
            $0.cognito.authenticate = mock
        } operation: {
            try app.test(.POST, "login", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword"])
            }, afterResponse: { res in
                if let cookieHeader = res.headers.first(name: .setCookie) {
                    XCTAssertTrue(cookieHeader.contains("HttpOnly"))
                    XCTAssertTrue(cookieHeader.contains("Secure"))
                }
            })
        }
    }
    
    func test_login_soto_error() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in throw SotoCognitoError.unauthorized(reason: "reason") }
            $0.cognito.authenticate = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "login", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .unauthorized)
            })
        }
    }
    
    func test_login_some_aws_client_error() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in throw AWSClientError.accessDenied }
            $0.cognito.authenticate = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "login", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .unauthorized)
            })
        }
    }
    
    func test_login_throw_other_error() throws {
        struct SomeError: Error {}
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> CognitoAuthenticateResponse = { _, _, _ in throw SomeError() }
            $0.cognito.authenticate = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "login", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .unauthorized)
            })
        }
    }
    
    func test_signup_successful_view_change() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void = { _, _, _ in }
            $0.cognito.signup = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "signup", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertTrue(res.body.string.contains("Verify"))
            })
        }
    }
    
    func test_signup_some_aws_error() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void = { _, _, _ in throw AWSClientError.accessDenied }
            $0.cognito.signup = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "signup", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword"])
            }, afterResponse: { res in
                XCTAssertTrue(res.body.string.contains("There was an error"))
            })
        }
    }
    
    func test_signup_throw_some_error() throws {
        struct SomeError: Error {}
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void = { _, _, _ in throw SomeError() }
            $0.cognito.signup = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "signup") { res in
                XCTAssertTrue(res.body.string.contains("error"))
            }
        }
    }
    
    func test_reset_password_successful_view_change() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String, _ confirmationCode: String) async throws -> Void = { _, _, _, _ in }
            $0.cognito.resetPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "reset-password", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword", "confirmationCode": "123"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertTrue(res.body.string.contains("Successfully changed password"))
            })
        }
    }
    
    func test_reset_pass_throws_aws_error() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String, _ confirmationCode: String) async throws -> Void = { _, _, _, _ in throw AWSClientError.accessDenied }
            $0.cognito.resetPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "reset-password", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword", "confirmationCode": "123"])
            }, afterResponse: { res in
                XCTAssertTrue(res.body.string.contains("There was an error"))
            })
        }
    }
    
    func test_reset_pass_throws_other_error() throws {
        try withDependencies {
            struct SomeError: Error {}
            let mock: @Sendable (_ req: Request, _ username: String, _ password: String, _ confirmationCode: String) async throws -> Void = { _, _, _, _ in throw SomeError() }
            $0.cognito.resetPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "reset-password", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword", "confirmationCode": "123"])
            }, afterResponse: { res in
                XCTAssertTrue(res.body.string.contains("An unknown error occurred"))
            })
        }
    }
    
    func test_forgot_pass_successful_view_change() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String) async throws -> Void = { _, _ in }
            $0.cognito.forgotPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "forgot-password", beforeRequest: { req in try req.content.encode(["email": "testemail"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertTrue(res.body.string.contains("Reset Password"))
            })
        }
    }
    
    func test_forgot_pass_throws() throws {
        try withDependencies {
            struct SomeError: Error {}
            let mock: @Sendable (_ req: Request, _ username: String) async throws -> Void = { _, _ in throw SomeError() }
            $0.cognito.forgotPassword = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "forgot-password", beforeRequest: { req in try req.content.encode(["email": "testemail"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertTrue(res.body.string.contains("An error occurred"))
            })
        }
    }
    
    func test_logout_successful_redirect() throws {
        try app.test(.POST, "logout") { res in
            XCTAssertEqual(res.status, .seeOther)
            if let location = res.headers.first(name: .location) {
                XCTAssertEqual("/", location)
            }
        }
    }
    
    func test_logout_session_destroyed() throws {
        try app.test(.POST, "logout") { res in
            let cookie = res.headers.setCookie?["vapor-session"]
            XCTAssertNil(cookie)
        }
    }
    
    func test_verify_successful_view_Change() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ confirmationCode: String) async throws -> Void = { _, _, _ in }
            $0.cognito.confirmSignUp = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "verify", beforeRequest: { req in try req.content.encode(["email": "testemail", "confirmationCode": "123"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertTrue(res.body.string.contains("Successfully confirmed signup"))
            })
        }
    }
    
    func test_verify_throws_aws_error() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request, _ username: String, _ confirmationCode: String) async throws -> Void = { _, _, _ in throw AWSClientError.accessDenied }
            $0.cognito.confirmSignUp = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "verify", beforeRequest: { req in try req.content.encode(["email": "testemail", "confirmationCode": "123"])
            }, afterResponse: { res in
                XCTAssertTrue(res.body.string.contains("There was an error"))
            })
        }
    }
    
    func test_verify_throws_some_error() throws {
        try withDependencies {
            struct SomeError: Error {}
            let mock: @Sendable (_ req: Request, _ username: String, _ confirmationCode: String) async throws -> Void = { _, _, _ in throw SomeError() }
            $0.cognito.confirmSignUp = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "verify", beforeRequest: { req in try req.content.encode(["email": "testemail", "confirmationCode": "123"])
            }, afterResponse: { res in
                XCTAssertTrue(res.body.string.contains("An unknown error occurred"))
            })
        }
    }
    
    func test_delete_successful_redirect() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request) async throws -> Void = { _ in }
            $0.cognito.deleteUser = mock
        } operation: {
            try app.test(.POST, "delete") { res in
                XCTAssertEqual(res.status, .seeOther)
                if let location = res.headers.first(name: .location) {
                    XCTAssertEqual("/", location)
                }
            }
        }
    }
    
    func test_delete_session_destroyed() throws {
        try withDependencies {
            let mock: @Sendable (_ req: Request) async throws -> Void = { _ in }
            $0.cognito.deleteUser = mock
        } operation: {
            try app.test(.POST, "delete") { res in
                let cookie = res.headers.setCookie?["vapor-session"]
                XCTAssertNil(cookie)
            }
        }
    }
    
    func test_delete_throws() throws {
        try withDependencies {
            struct SomeError: Error {}
            let mock: @Sendable (_ req: Request) async throws -> Void = { _ in throw SomeError() }
            $0.cognito.deleteUser = mock
            $0.environment.dbId = { nil }
        } operation: {
            try app.test(.POST, "delete") { res in
                XCTAssertEqual(res.status, .internalServerError)
                XCTAssertTrue(res.body.string.contains("An unknown error occurred"))
            }
        }
    }
}

