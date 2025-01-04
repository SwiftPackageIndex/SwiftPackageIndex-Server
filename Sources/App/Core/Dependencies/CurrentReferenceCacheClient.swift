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
import DependenciesMacros
import NIOCore
@preconcurrency import RediStack


@DependencyClient
struct CurrentReferenceCacheClient {
    var set: @Sendable (_ owner: String, _ repository: String, _ reference: String) async -> Void
    var get: @Sendable (_ owner: String, _ repository: String) async -> String?
}


extension CurrentReferenceCacheClient: DependencyKey {
    static var liveValue: CurrentReferenceCacheClient {
        .init(
            set: { owner, repository, reference async in
                await Redis.shared?.set(owner: owner, repository: repository, reference: reference)
            },
            get: { owner, repository in
                await Redis.shared?.get(owner: owner, repository: repository)
            }
        )
    }
}


extension CurrentReferenceCacheClient: TestDependencyKey {
    static var testValue: Self { Self() }
}


extension DependencyValues {
    var currentReferenceCache: CurrentReferenceCacheClient {
        get { self[CurrentReferenceCacheClient.self] }
        set { self[CurrentReferenceCacheClient.self] = newValue }
    }
}


extension CurrentReferenceCacheClient {
    actor Redis {
        var client: RedisClient
        static private var task: Task<Redis?, Never>?

        static var shared: Redis? {
            get async {
                if let task {
                    return await task.value
                }
                let task = Task<Redis?, Never> {
                    var attemptsLeft = maxConnectionAttempts
                    while attemptsLeft > 0 {
                        do {
                            return try await Redis()
                        } catch {
                            attemptsLeft -= 1
                            Current.logger().warning("Redis connection failed, \(attemptsLeft) attempts left. Error: \(error)")
                            try? await Task.sleep(for: .milliseconds(500))
                        }
                    }
                    return nil
                }
                self.task = task
                return await task.value
            }
        }

        private init() async throws {
            let connection = RedisConnection.make(
                configuration: try .init(hostname: Redis.hostname),
                boundEventLoop: NIOSingletons.posixEventLoopGroup.any()
            )
            self.client = try await connection.get()
        }

        static let expirationInSeconds = 5*60
        static let hostname = "redis"
        static let maxConnectionAttempts = 3

        func set(owner: String, repository: String, reference: String) async -> Void {
            let key = "\(owner)/\(repository)".lowercased()
            let buffer = ByteBuffer(string: reference)
            try? await client.setex(.init(key),
                                    to: RESPValue.bulkString(buffer),
                                    expirationInSeconds: Self.expirationInSeconds).get()
        }

        func get(owner: String, repository: String) async -> String? {
            let key = "\(owner)/\(repository)".lowercased()
            return try? await client.get(.init(key)).map(\.string).get()
        }
    }
}
