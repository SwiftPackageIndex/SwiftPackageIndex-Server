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


class ManageTests: AppTestCase {

    func test_portal_route_protected() throws {
        try app.test(.GET, "portal") { res in
            XCTAssertEqual(res.status, .seeOther)
        }
    }
    
    func test_login_successful_redirect() throws {
        // not throwing in auth is a successful authentication and user
        // should be redirected
        try withDependencies {
            var mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void = { _, _, _ in }
            $0.cognito.authenticate = mock
        } operation: {
            try app.test(.POST, "login", beforeRequest: { req in try req.content.encode(["email": "testemail", "password": "testpassword"])
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .seeOther)
            })
        }
    }
    
    func test_login_throws() throws {
        struct SomeError: Error {}
        try withDependencies {
            var mock: @Sendable (_ req: Request, _ username: String, _ password: String) async throws -> Void = { _, _, _ in throw SomeError() }
            $0.cognito.authenticate = mock
        } operation: {
            try app.test(.POST, "login") { res in
                XCTAssertEqual(res.status, .unauthorized)
            }
        }
    }
}

