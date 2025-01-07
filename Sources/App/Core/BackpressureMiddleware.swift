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

import Dependencies
import Redis
import Vapor


final class BackpressureMiddleware: AsyncMiddleware {
    let configuration: Configuration

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let cfray = request.headers.first(name: "cf-ray") else {
            return try await next.respond(to: request)
        }
        let epochSeconds = Int(Date().timeIntervalSince1970)
        let combinedKey = "\(cfray):\(epochSeconds)"

        let slidingWindow = configuration.slidingWindow

        @Dependency(\.redis) var redis

        guard var countOverWindow = try? await redis.increment(key: combinedKey) else {
            request.logger.log(level: .warning, "BackpressureMiddleware failed to increment key '\(combinedKey)'.")
            return try await next.respond(to: request)
        }
        if countOverWindow == 1 {
            _ = try? await redis.expire(key: combinedKey, after: .seconds(3600))
        }

        for i in epochSeconds - slidingWindow ..< epochSeconds {
            let key = "\(cfray):\(i)"
            if let value = (try? await redis.get(key)).flatMap(Int.init) {
                countOverWindow += value
            }
        }


        if countOverWindow >= configuration.requestLimit {
            request.logger.log(level: .warning, "BackpressureMiddleware acting on request with cf-ray '\(cfray)' due to \(countOverWindow) requests in the last \(slidingWindow) seconds.")

            switch configuration.mode {
                case .block:
                    throw Abort(.tooManyRequests)
                case .delay(let duration):
                    try await Task.sleep(for: .init(seconds: duration))
                    return try await next.respond(to: request)
            }
        } else {
            return try await next.respond(to: request)
        }
    }

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    struct Configuration: Codable {
        var mode: Mode
        var requestLimit: Int
        var slidingWindow: Int  // in seconds

        enum Mode: Codable {
            case block
            case delay(seconds: Double)
        }
    }
}


extension Duration {
    init(seconds: Double) {
        self = .microseconds(seconds/1e-6)
    }
}
