@testable import App

import Foundation


extension Github.Metadata {
    static let mock: Self = .init(
        issues: [],
        openPullRequests: [],
        repo: .init(defaultBranch: "main",
                    description: "desc",
                    forksCount: 1,
                    license: .init(key: "mit"),
                    openIssues: 3,
                    parent: nil,
                    stargazersCount: 2
        )
    )
    
    static func mock(for package: Package) -> Self {
        // populate with some mock data derived from the package
        .init(
            issues: [],
            openPullRequests: [],
            repo: .init(defaultBranch: "main",
                        description: "This is package " + package.url,
                        forksCount: package.url.count,
                        license: .init(key: "mit"),
                        openIssues: 3,
                        parent: nil,
                        stargazersCount: package.url.count + 1
            )
        )
    }
}


extension Github._Metadata {
    static let mock: Self = .init(defaultBranch: "main",
                                  forks: 1,
                                  issuesClosedAtDates: [],
                                  license: .mit,
                                  openIssues: 3,
                                  openPullRequests: 0,
                                  owner: "packageOwner",
                                  pullRequestsClosedAtDates: [],
                                  name: "packageName",
                                  stars: 2,
                                  summary: "desc")

    static func mock(for package: Package) -> Self {
        .init(defaultBranch: "main",
              forks: package.url.count,
              issuesClosedAtDates: [],
              license: .mit,
              openIssues: 3,
              openPullRequests: 0,
              owner: "packageOwner",
              pullRequestsClosedAtDates: [],
              name: "packageName",
              stars: package.url.count + 1,
              summary: "This is package " + package.url)
    }

    init(defaultBranch: String,
         forks: Int,
         issuesClosedAtDates: [Date],
         license: License,
         openIssues: Int,
         openPullRequests: Int,
         owner: String,
         pullRequestsClosedAtDates: [Date],
         name: String,
         stars: Int,
         summary: String) {
        self = .init(
            repository: .init(closedIssues: .init(closedAtDates: issuesClosedAtDates),
                              closedPullRequests: .init(closedAtDates: pullRequestsClosedAtDates),
                              createdAt: Date(),
                              defaultBranchRef: .init(name: defaultBranch),
                              description: summary,
                              forkCount: forks,
                              isArchived: false,
                              isFork: false,
                              licenseInfo: .init(name: license.fullName, key: license.rawValue, url: ""),
                              mergedPullRequests: .init(closedAtDates: []),
                              name: name,
                              openIssues: .init(totalCount: openIssues),
                              openPullRequests: .init(totalCount: openPullRequests),
                              owner: .init(login: owner),
                              stargazerCount: stars),
            rateLimit: .init(remaining: 5000)
        )
    }
}
