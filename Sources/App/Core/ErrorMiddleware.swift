// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Plot
import Vapor


// based on LeafErrorMiddleware
// https://github.com/brokenhandsio/leaf-error-middleware

public final class ErrorMiddleware: AsyncMiddleware {
    
    public func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: req)
        } catch let error as AbortError where error.status.code >= 400 {
            let statusCode = error.status.code
            let isCritical = (statusCode >= 500)

            if isCritical {
                Task.detached {
                    try await Current.reportError(req.client, .critical, error).get()
                }
                Current.logger()?.critical("ErrorPage.View \(statusCode): \(error.localizedDescription)")
            } else {
                Current.logger()?.error("ErrorPage.View \(statusCode): \(error.localizedDescription)")
            }

            return ErrorPage.View(path: req.url.path, error: error)
                .document()
                .encodeResponse(for: req, status: error.status)
        }
    }

}
