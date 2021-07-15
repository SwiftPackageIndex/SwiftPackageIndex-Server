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

public final class ErrorMiddleware: Middleware {
    
    public func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        next.respond(to: req)
            .flatMapError { error in
                let abortError = error as? AbortError ?? Abort(.internalServerError)
                let statusCode = abortError.status.code

                let reportError = statusCode >= 500
                    ? Current.reportError(req.client, .critical, error)
                    : req.eventLoop.future()

                return reportError.flatMap {
                    statusCode >= 500
                        ? Current.logger()?.critical("ErrorPage.View \(statusCode): \(error.localizedDescription)")
                        : Current.logger()?.error("ErrorPage.View \(statusCode): \(error.localizedDescription)")
                    return ErrorPage.View(path: req.url.path, error: abortError)
                        .document()
                        .encodeResponse(for: req, status: abortError.status)
                }
            }
    }

}
