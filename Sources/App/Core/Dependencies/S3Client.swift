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
struct S3Client {
#warning("drop client parameter")
    var fetchS3Readme: @Sendable (_ client: Client, _ owner: String, _ repository: String) async throws -> String
}

extension S3Client: DependencyKey {
    static var liveValue: Self {
        .init(
            fetchS3Readme: { client, owner, repo in
                try await S3Readme.fetchReadme(client:client, owner: owner, repository: repo)
            }
        )
    }
}

extension S3Client: TestDependencyKey {
    static var testValue: Self { Self() }
}

extension DependencyValues {
    var s3Client: S3Client {
        get { self[S3Client.self] }
        set { self[S3Client.self] = newValue }
    }
}


