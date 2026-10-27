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


/// A baseline `Content-Security-Policy` that restricts plugins, `<base>`, framing and form targets.
///
/// It leaves `script-src` and `style-src` open: pages use an inline analytics script, Vega compiles its
/// expressions with `new Function` and Mermaid injects `<style>`, so locking those down comes later.
struct ContentSecurityPolicyMiddleware: AsyncMiddleware {

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        response.headers.replaceOrAdd(
            name: "Content-Security-Policy",
            value: "object-src 'none'; base-uri 'self'; frame-ancestors 'self'; form-action 'self'"
        )
        return response
    }
}
