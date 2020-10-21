@testable import App

import Vapor


extension AppEnvironment {
    static let mock: Self = .init(
        allowBuildTriggers: { true },
        builderToken: { nil },
        buildTriggerDownscaling: { 1.0 },
        date: Date.init,
        fetchPackageList: { _ in
            .just(value: ["https://github.com/finestructure/Gala",
                          "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"].asURLs)
        },
        fetchLicense: { _, _ in .just(value: .init(htmlUrl: "https://github.com/foo/bar/blob/main/LICENSE")) },
        fetchMetadata: { _, _ in .just(value: .mock) },
        fileManager: .mock,
        getStatusCount: { _, _ in .just(value: 100) },
        githubToken: { nil },
        gitlabApiToken: { nil },
        gitlabPipelineToken: { nil },
        gitlabPipelineLimit: { Constants.defaultGitlabPipelineLimit },
        random: Double.random,
        reportError: { _, _, _ in .just(value: ()) },
        rollbarToken: { nil },
        rollbarLogLevel: { .critical },
        shell: .mock,
        siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" }
    )
}
