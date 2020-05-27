@testable import App


extension Github.Metadata {
    static let mock: Self = .init(
        issues: [],
        openPullRequests: [],
        repo: .init(defaultBranch: "master",
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
            repo: .init(defaultBranch: "master",
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
