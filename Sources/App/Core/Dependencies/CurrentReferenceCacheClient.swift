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


@DependencyClient
struct CurrentReferenceCacheClient {
    var set: @Sendable (_ owner: String, _ repository: String, _ reference: String?) async -> Void
    var get: @Sendable (_ owner: String, _ repository: String) async -> String?
}


extension CurrentReferenceCacheClient: DependencyKey {
    static let timeToLive: Duration = .seconds(5*60)

    static var liveValue: CurrentReferenceCacheClient {
        .init(
            set: { owner, repository, reference async in
                @Dependency(\.redis) var redis
                try? await redis.set(key: getKey(owner: owner, repository: repository),
                                     value: reference,
                                     expiresIn: timeToLive)
            },
            get: { owner, repository in
                @Dependency(\.redis) var redis
                return try? await redis.get(key: getKey(owner: owner, repository: repository))
            }
        )
    }

    static func getKey(owner: String, repository: String) -> String {
        "\(owner)/\(repository)".lowercased()
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


#if DEBUG
extension CurrentReferenceCacheClient {
    static var disabled: Self {
        .init(set: { _, _, _ in }, get: { _, _ in nil })
    }

    static var inMemory: Self {
        .init(
            set: { owner, repository, reference in
                _cache.withValue {
                    $0[getKey(owner: owner, repository: repository)] = reference
                }
            },
            get: { owner, repository in
                _cache.withValue {
                    $0[getKey(owner: owner, repository: repository)]
                }
            }
        )
    }

    nonisolated(unsafe) static var _cache = LockIsolated<[String: String]>([:])
}
#endif
