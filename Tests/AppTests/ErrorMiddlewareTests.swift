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

import Dependencies
import Testing
import Vapor


extension AllTests.ErrorMiddlewareTests {

    func setup(_ app: Application) async throws {
        // set up some test routes
        app.get("ok") { _ in return "ok" }
        app.get("404") { req async throws -> Response in throw Abort(.notFound) }
        app.get("500") { req async throws -> Response in throw Abort(.internalServerError) }
    }

    @Test func custom_routes() async throws {
        try await withApp(setup) { app in
            // Test to ensure the test routes we've set up in setUpWithError are in effect
            try await app.test(.GET, "ok", afterResponse: { response async in
                #expect(response.status == .ok)
                #expect(response.body.asString() == "ok")
            })
        }
    }

    @Test func html_error() async throws {
        // Test to ensure errors are converted to html error pages via the ErrorMiddleware
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp(setup) { app in
                try await app.test(.GET, "404", afterResponse: { response async in
                    #expect(response.content.contentType == .html)
                    #expect(response.body.asString().contains("404 - Not Found"))
                })
            }
        }
    }

    @Test func status_code() async throws {
        // Ensure we're still reporting the actual status code even when serving html pages
        // (Status is important for Google ranking, see
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/323)
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withApp(setup) { app in
                try await app.test(.GET, "404", afterResponse: { response async in
                    #expect(response.status == .notFound)
                    #expect(response.content.contentType == .html)
                })
                try await app.test(.GET, "500", afterResponse: { response async in
                    #expect(response.status == .internalServerError)
                    #expect(response.content.contentType == .html)
                })
            }
        }
    }

}
