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
import IssueReporting
import Vapor


// We currently cannot use @DependencyClient here due to
// https://github.com/pointfreeco/swift-dependencies/discussions/324
//@DependencyClient
struct S3Client {
#warning("drop client parameter")
    var fetchReadme: @Sendable (_ client: Client, _ owner: String, _ repository: String) async throws -> String
    var storeS3Readme: @Sendable (_ owner: String, _ repository: String, _ readme: String) async throws(S3Readme.Error) -> String = { _, _, _ in
        reportIssue("storeS3Readme"); return ""
    }
}

extension S3Client: DependencyKey {
    static var liveValue: Self {
        .init(
            fetchReadme: { client, owner, repo in
                try await S3Readme.fetchReadme(client:client, owner: owner, repository: repo)
            },
            storeS3Readme: { owner, repo, readme throws(S3Readme.Error) in
                try await S3Readme.storeReadme(owner: owner, repository: repo, readme: readme)
            }
        )
    }
}

extension S3Client: TestDependencyKey {
    static var testValue: Self {
        .init(
            fetchReadme: { _, _, _ in unimplemented(); return "" },
            storeS3Readme: { _, _, _ in unimplemented("storeS3Readme"); return "" }
        )
    }
}

extension DependencyValues {
    var s3: S3Client {
        get { self[S3Client.self] }
        set { self[S3Client.self] = newValue }
    }
}


