@testable import App

import Foundation


extension Github.Metadata {
    static let mock: Self = .init(defaultBranch: "main",
                                  forks: 1,
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
                                  summary: "desc",
                                  isInOrganization: false)

    static func mock(for package: Package) -> Self {
        let (owner, name) = try! Github.parseOwnerName(url: package.url)
        return .init(defaultBranch: "main",
                     forks: package.url.count,
                     issuesClosedAtDates: [],
                     license: .mit,
                     openIssues: 3,
                     openPullRequests: 0,
                     owner: owner,
                     pullRequestsClosedAtDates: [],
                     releases: [],
                     repositoryTopics: [],
                     name: name,
                     stars: package.url.count + 1,
                     summary: "This is package " + package.url,
                     isInOrganization: false)
    }

    init(defaultBranch: String,
         forks: Int,
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
         summary: String,
         isInOrganization: Bool
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
                              isArchived: false,
                              isFork: false,
                              licenseInfo: .init(name: license.fullName, key: license.rawValue),
                              mergedPullRequests: .init(closedAtDates: []),
                              name: name,
                              openIssues: .init(totalCount: openIssues),
                              openPullRequests: .init(totalCount: openPullRequests),
                              owner: .init(login: owner, name: owner, avatarUrl: "https://avatars.githubusercontent.com/u/61124617?s=200&v=4"),
                              releases: .init(nodes: releases),
                              repositoryTopics: .init(totalCount: topics.count,
                                                      nodes: topics),
                              stargazerCount: stars,
                              isInOrganization: isInOrganization)
        )
    }
}
