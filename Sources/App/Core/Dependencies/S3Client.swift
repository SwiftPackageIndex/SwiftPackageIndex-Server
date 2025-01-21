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


// We currently cannot use @DependencyClient here due to
// https://github.com/pointfreeco/swift-dependencies/discussions/324
//@DependencyClient
struct S3Client {
    var fetchReadme: @Sendable (_ owner: String, _ repository: String) async throws -> String
    var storeReadme: @Sendable (_ owner: String, _ repository: String, _ readme: String) async throws(S3Readme.Error) -> String = { _, _, _ in
        reportIssue("storeS3Readme"); return ""
    }
    var storeReadmeImages: @Sendable (_ imagesToCache: [Github.Readme.ImageToCache]) async throws(S3Readme.Error) -> Void
}


extension S3Client: DependencyKey {
    static var liveValue: Self {
        .init(
            fetchReadme: { owner, repo in
                try await S3Readme.fetchReadme(owner: owner, repository: repo)
            },
            storeReadme: { owner, repo, readme throws(S3Readme.Error) in
                try await S3Readme.storeReadme(owner: owner, repository: repo, readme: readme)
            },
            storeReadmeImages: { images throws(S3Readme.Error) in
                try await S3Readme.storeReadmeImages(imagesToCache: images)
            }
        )
    }
}


extension S3Client: TestDependencyKey {
    static var testValue: Self {
        .init(
            fetchReadme: { _, _ in unimplemented(); return "" },
            storeReadme: { _, _, _ in unimplemented("storeS3Readme"); return "" },
            storeReadmeImages: { _ throws(S3Readme.Error) in unimplemented("storeS3ReadmeImages") }
        )
    }
}


extension DependencyValues {
    var s3: S3Client {
        get { self[S3Client.self] }
        set { self[S3Client.self] = newValue }
    }
}


