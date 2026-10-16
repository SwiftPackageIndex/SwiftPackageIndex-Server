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
            try await app.testing().test(.GET, "ok") { res async throws in
                let policy = ParsedContentSecurityPolicy(try #require(res.headers.first(name: "Content-Security-Policy")))
                #expect(policy.directives["object-src"] == ["'none'"])
                #expect(policy.directives["base-uri"] == ["'self'"])
                #expect(policy.directives["frame-ancestors"] == ["'self'"])
                #expect(policy.directives["form-action"] == ["'self'"])
            }
        }
    }

    /// Without `'unsafe-eval'` or `'unsafe-inline'`, injected markup can't run script: no `<script>`, no
    /// `onerror=`, no `javascript:` URL, and no library compiling a string it was handed.
    @Test func pagesRunNoScriptFromStrings() async throws {
        try await withSPIApp(setup) { app in
            try await app.testing().test(.GET, "ok") { res async throws in
                let policy = ParsedContentSecurityPolicy(try #require(res.headers.first(name: "Content-Security-Policy")))
                let sources = try #require(policy.directives["script-src"])
                #expect(!sources.contains("'unsafe-eval'"))
                #expect(!sources.contains("'unsafe-inline'"))
            }
        }
    }

    @Test func pagesRunTheirOwnScripts() async throws {
        try await withDependencies {
            $0.environment.dbId = { nil }
            $0.environment.maintenanceMessage = { nil }
        } operation: {
            try await withSPIApp { app in
                try await app.testing().test(.GET, "/") { res async throws in
                    let policy = try #require(res.headers.first(name: "Content-Security-Policy"))
                    let blocked = try ParsedContentSecurityPolicy(policy).blockedScripts(in: res.body.string)
                    #expect(blocked == [])
                }
            }
        }
    }

    @Test func pagesRunTheProductionAnalyticsScripts() async throws {
        try await withSPIApp(setup) { app in
            try await app.testing().test(.GET, "ok") { res async throws in
                let policy = try #require(res.headers.first(name: "Content-Security-Policy"))
                let blocked = try ParsedContentSecurityPolicy(policy).blockedScripts(in: PublicPage.analyticsScriptTags)
                #expect(blocked == [])
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
