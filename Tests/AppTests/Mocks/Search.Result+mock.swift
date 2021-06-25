@testable import App


extension Search.Result {
    static func mock(packageId: Package.Id?,
                     packageName: String?,
                     packageURL: String?,
                     repositoryName: String?,
                     repositoryOwner: String?,
                     summary: String?) -> Self {
            .package(
                .init(
                    packageId: packageId,
                    packageName: packageName,
                    packageURL: packageURL,
                    repositoryName: repositoryName,
                    repositoryOwner: repositoryOwner,
                    summary: summary
                )
            )
    }
}
