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


extension AllTests.ContentSecurityPolicyMiddlewareTests {

    func setup(_ app: Application) async throws {
        app.get("ok") { _ in "ok" }
        app.get("404") { _ async throws -> Response in throw Abort(.notFound) }
    }

    @Test func pagesRefuseFramingPluginsAndForeignBaseOrFormTargets() async throws {
        try await withSPIApp(setup) { app in
            try await app.testing().test(.GET, "ok") { res async in
                #expect(res.headers.first(name: "Content-Security-Policy")
                        == "object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'")
            }
        }
    }

    @Test func errorPagesCarryThePolicyToo() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
        } operation: {
            try await withSPIApp(setup) { app in
                try await app.testing().test(.GET, "404") { res async in
                    #expect(res.status == .notFound)
                    #expect(res.headers.first(name: "Content-Security-Policy") != nil)
                }
            }
        }
    }
}
