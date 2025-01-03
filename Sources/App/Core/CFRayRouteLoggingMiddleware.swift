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


// Replica of the Vapor RouteLoggingMiddleware that's tweaked to explicitly expose the cf-ray header in the logger metadata for the request.
public final class CFRayRouteLoggingMiddleware: Middleware {
    public let logLevel: Logger.Level

    public init(logLevel: Logger.Level = .info) {
        self.logLevel = logLevel
    }
    
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let cfray = request.headers.first(name: "cf-ray") else {
            return next.respond(to: request)
        }
        request.logger[metadataKey: "cf-ray"] = .string(cfray)
        request.logger.log(level: self.logLevel, "\(request.method) \(request.url.path.removingPercentEncoding ?? request.url.path)")
        return next.respond(to: request)
    }
}
