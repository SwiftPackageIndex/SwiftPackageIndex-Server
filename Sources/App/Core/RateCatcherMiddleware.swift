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
import Redis

final class RateCatcherMiddleware: AsyncMiddleware {
    
    let windowSize: Int // in seconds
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let cfray = request.headers.first(name: "cf-ray") else {
            return try await next.respond(to: request)
        }
        let seconds: Int = Int(Date().timeIntervalSince1970)
        let combinedKey: RedisKey = "\(cfray):\(seconds)"
        
        let countOverWindow: Int = try await request.redis.increment(combinedKey)
        for i in seconds - windowSize ..< seconds {
            let key: RedisKey = "\(cfray):\(i)"
            countOverWindow += try await request.redis.get(key, as: Int.self)
        }
            
        if countOverWindow > 999 {
            request.logger.log(level: .warning, "RateCatcherMiddleware blocking request with cf-ray \(cfray) due to \(countOverWindow) requests in the last \(windowSize) seconds.")
            throw Abort(.tooManyRequests)
        } else {
            return try await next.respond(to: request)
        }
    }
    
    init(windowSize: Int) {
        self.windowSize = windowSize
    }
}
