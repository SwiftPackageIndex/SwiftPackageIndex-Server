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

import Vapor


/// A `Content-Security-Policy` that restricts plugins, `<base>`, framing, form targets and scripts, unless
/// the route set its own.
///
/// It leaves `style-src` open: Mermaid, vega-tooltip and Turbo's progress bar all inject `<style>`.
struct ContentSecurityPolicyMiddleware: AsyncMiddleware {

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        if !response.headers.contains(name: .contentSecurityPolicy) {
            response.headers.add(name: .contentSecurityPolicy, value: Self.pagePolicy)
        }
        return response
    }

    /// The hashes are the production analytics scripts in ``PublicPage/analyticsScriptTags``.
    static let pagePolicy = policy(scriptSources: [
        "'sha256-sriZsXN1Y/G5VuC6lkbt1PHDxFN1loZa4Vdx24xSR6o='",
        "'sha256-vOUCijeZnvKQPZiIb624x4B3Y2cu2UDYb/HYIuDw4i0='",
    ])

    /// DocC's inline `baseUrl` script differs per package, so it can't be hashed, and a hash in the list
    /// would switch `'unsafe-inline'` off.
    static let documentationPolicy = policy(scriptSources: ["'unsafe-inline'"])

    private static func policy(scriptSources: [String]) -> String {
        [
            "object-src 'none'",
            "base-uri 'self'",
            "frame-ancestors 'self'",
            "form-action 'self'",
            "script-src " + (["'self'", "https://developer.apple.com"] + scriptSources).joined(separator: " "),
        ].joined(separator: "; ")
    }
}
