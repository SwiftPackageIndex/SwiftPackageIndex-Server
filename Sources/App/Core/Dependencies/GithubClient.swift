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
struct GithubClient {
    var fetchLicense: @Sendable (_ owner: String, _ repository: String) async -> Github.License?
    var fetchMetadata: @Sendable (_ owner: String, _ repository: String) async throws(Github.Error) -> Github.Metadata = { _,_ in reportIssue("fetchMetadata"); return .init() }
    var fetchReadme: @Sendable (_ owner: String, _ repository: String) async -> Github.Readme?
    var token: @Sendable () -> String?
}


extension GithubClient: DependencyKey {
    static var liveValue: Self {
        .init(
            fetchLicense: { owner, repo in await Github.fetchLicense(owner: owner, repository: repo) },
            fetchMetadata: { owner, repo throws(Github.Error) in try await Github.fetchMetadata(owner: owner, repository: repo) },
            fetchReadme: { owner, repo in await Github.fetchReadme(owner: owner, repository: repo) },
            token: { Environment.get("GITHUB_TOKEN") }
        )
    }
}


extension GithubClient: TestDependencyKey {
    static var testValue: Self {
        .init(
            fetchLicense: { _, _ in unimplemented("fetchLicense"); return nil },
            fetchMetadata: { _, _ in unimplemented("fetchMetadata"); return .init() },
            fetchReadme: { _, _ in unimplemented("fetchReadme"); return nil },
            token: { unimplemented("token"); return nil }
        )
    }
}


extension DependencyValues {
    var github: GithubClient {
        get { self[GithubClient.self] }
        set { self[GithubClient.self] = newValue }
    }
}
