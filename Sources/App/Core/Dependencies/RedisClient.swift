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

import NIOCore
@preconcurrency import RediStack
import Dependencies
import DependenciesMacros


@DependencyClient
struct RedisClient {
    var set: @Sendable (_ key: String, _ value: String?, Duration?) async throws -> Void
    var get: @Sendable (_ key: String) async throws -> String?
    var expire: @Sendable (_ key: String, _ after: Duration) async throws -> Bool
    var increment: @Sendable (_ key: String, _ by: Int) async throws -> Int
}


extension RedisClient {
    func set(key: String, value: String?, expiresIn: Duration? = nil) async throws {
        try await set(key: key, value: value, expiresIn)
    }

    func increment(key: String) async throws -> Int {
        try await increment(key: key, by: 1)
    }
}


extension RedisClient: DependencyKey {
    static var liveValue: RedisClient {
        .init(
            set: { key, value, expiresIn in
                try await Redis.shared.set(key: key, value: value, expiresIn: expiresIn)
            },
            get: { key in try await Redis.shared.get(key: key) },
            expire: { key, ttl in try await Redis.shared.expire(key: key, after: ttl) },
            increment: { key, value in try await Redis.shared.increment(key: key, by: value) }
        )
    }
}


extension RedisClient: TestDependencyKey {
    static var testValue: Self { Self() }
}


extension DependencyValues {
    var redis: RedisClient {
        get { self[RedisClient.self] }
        set { self[RedisClient.self] = newValue }
    }
}


#if DEBUG
extension RedisClient {
    static var disabled: Self {
        .init(set: { _, _, _ in },
              get: { _ in nil },
              expire: { _, _ in true },
              increment: { _, value in value })
    }
}
#endif


private actor Redis {
    var client: RediStack.RedisClient
    static private var task: Task<Redis, Swift.Error>?

    static var shared: Redis {
        get async throws {
            if let task {
                return try await task.value
            }
            let task = Task<Redis, Swift.Error> {
                var attemptsLeft = maxConnectionAttempts
                while attemptsLeft > 0 {
                    do {
                        return try await Redis()
                    } catch {
                        attemptsLeft -= 1
                        @Dependency(\.logger) var logger
                        logger.warning("Redis connection failed, \(attemptsLeft) attempts left. Error: \(error)")
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
                throw Error.unavailable
            }
            self.task = task
            return try await task.value
        }
    }

    enum Error: Swift.Error {
        case unavailable
    }

    private init() async throws {
        @Dependency(\.environment) var environment
        let connection = RedisConnection.make(
            configuration: try .init(hostname: environment.redisHostname()),
            boundEventLoop: NIOSingletons.posixEventLoopGroup.any()
        )
        self.client = try await connection.get()
    }

    static let maxConnectionAttempts = 3

    func set(key: String, value: String?, expiresIn: Duration?) async {
        if let value {
            let buffer = ByteBuffer(string: value)
            let value = RESPValue.bulkString(buffer)
            if let expiresIn {
                let ttl = Int(expiresIn.components.seconds)
                try? await client.setex(.init(key), to: value, expirationInSeconds: ttl).get()
            } else {
                try? await client.set(.init(key), to: value).get()
            }
        } else {
            _ = try? await client.delete([.init(key)]).get()
        }
    }

    func get(key: String) async -> String? {
        return try? await client.get(.init(key)).map(\.string).get()
    }

    func expire(key: String, after ttl: Duration) async throws -> Bool {
        try await client.expire(.init(key), after: .init(ttl)).get()
    }

    func increment(key: String) async throws -> Int {
        try await client.increment(.init(key)).get()
    }

    func increment(key: String, by value: Int) async throws -> Int {
        try await client.increment(.init(key), by: value).get()
    }
}

