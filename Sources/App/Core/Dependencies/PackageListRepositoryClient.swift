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
import Vapor


@DependencyClient
struct PackageListRepositoryClient {
    var fetchCustomCollection: @Sendable (_ client: Client, _ url: URL) async throws -> [URL]
    var fetchCustomCollections: @Sendable (_ client: Client) async throws -> [CustomCollection.DTO]
    // TODO: move other package list dependencies here
}


extension PackageListRepositoryClient: DependencyKey {
    static var liveValue: PackageListRepositoryClient {
        .init(
            fetchCustomCollection: { client, url in
                try await client
                    .get(URI(string: url.absoluteString))
                    .content
                    .decode([URL].self, using: JSONDecoder())
            },
            fetchCustomCollections: { client in
                try await client
                    .get(Constants.customCollectionsUri)
                    .content
                    .decode([CustomCollection.DTO].self, using: JSONDecoder())
            }
        )
    }
}


extension PackageListRepositoryClient: Sendable, TestDependencyKey {
    static var testValue: Self { Self() }
}


extension DependencyValues {
    var packageListRepository: PackageListRepositoryClient {
        get { self[PackageListRepositoryClient.self] }
        set { self[PackageListRepositoryClient.self] = newValue }
    }
}

