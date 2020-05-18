@testable import App


extension Github.Metadata {
    static let mock: Self = .init(
        defaultBranch: "master",
        description: "desc",
        forksCount: 1,
        license: .init(key: "mit"),
        stargazersCount: 2,
        parent: nil
    )

    static func mock(for package: Package) -> Self {
        // populate with some mock data derived from the package
        .init(defaultBranch: "master",
              description: "This is package " + package.url,
              forksCount: package.url.count,
              license: .init(key: "mit"),
              stargazersCount: package.url.count + 1,
              parent: nil)
    }
}
