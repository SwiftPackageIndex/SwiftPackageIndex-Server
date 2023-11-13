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

@testable import App

import Foundation


extension Github.Metadata {
    static let mock: Self = .init(defaultBranch: "main",
                                  forks: 1,
                                  homepageUrl: nil,
                                  isInOrganization: false,
                                  issuesClosedAtDates: [],
                                  license: .mit,
                                  openIssues: 3,
                                  openPullRequests: 0,
                                  owner: "packageOwner",
                                  pullRequestsClosedAtDates: [],
                                  releases: [],
                                  repositoryTopics: [],
                                  name: "packageName",
                                  stars: 2,
                                  summary: "desc")

    static func mock(for packageUrl: String) -> Self {
        let (owner, name) = try! Github.parseOwnerName(url: packageUrl)
        return .init(defaultBranch: "main",
                     forks: packageUrl.count,
                     homepageUrl: nil,
                     isInOrganization: false,
                     issuesClosedAtDates: [],
                     license: .mit,
                     openIssues: 3,
                     openPullRequests: 0,
                     owner: owner,
                     pullRequestsClosedAtDates: [],
                     releases: [],
                     repositoryTopics: [],
                     name: name,
                     stars: packageUrl.count + 1,
                     summary: "This is package " + packageUrl)
    }

    init(defaultBranch: String,
         forks: Int,
         homepageUrl: String?,
         isInOrganization: Bool,
         issuesClosedAtDates: [Date],
         license: License,
         openIssues: Int,
         openPullRequests: Int,
         owner: String,
         pullRequestsClosedAtDates: [Date],
         releases: [ReleaseNodes.ReleaseNode] = [],
         repositoryTopics: [String] = [],
         name: String,
         stars: Int,
         summary: String
    ) {
        let topics = repositoryTopics
            .map {
                RepositoryTopicNodes.RepositoryTopic(
                    topic: RepositoryTopicNodes.RepositoryTopic.Topic(name: $0)
                )
            }
        self = .init(
            repository: .init(closedIssues: .init(closedAtDates: issuesClosedAtDates),
                              closedPullRequests: .init(closedAtDates: pullRequestsClosedAtDates),
                              defaultBranchRef: .init(name: defaultBranch),
                              description: summary,
                              forkCount: forks,
                              homepageUrl: homepageUrl,
                              isArchived: false,
                              isFork: false,
                              isInOrganization: isInOrganization,
                              licenseInfo: .init(name: license.fullName, key: license.rawValue),
                              mergedPullRequests: .init(closedAtDates: []),
                              name: name,
                              openIssues: .init(totalCount: openIssues),
                              openPullRequests: .init(totalCount: openPullRequests),
                              owner: .init(login: owner, name: owner, avatarUrl: "https://avatars.githubusercontent.com/u/61124617?s=200&v=4"),
                              releases: .init(nodes: releases),
                              repositoryTopics: .init(totalCount: topics.count,
                                                      nodes: topics),
                              stargazerCount: stars)
        )
    }
}

extension Github.Funding {
    static let mock: Self = .init(customUrls: ["example.com/funding/link"], github: ["GitHubUsername"])
}
