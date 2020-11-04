@testable import App

import NIO
import Vapor


extension AppEnvironment {
    static func mock(eventLoop: EventLoop) -> Self {
        .init(
            allowBuildTriggers: { true },
            builderToken: { nil },
            buildTriggerDownscaling: { 1.0 },
            date: Date.init,
            fetchPackageList: { _ in
                eventLoop.future(["https://github.com/finestructure/Gala",
                                      "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server"].asURLs)
            },
            fetchLicense: { _, _ in eventLoop.future(.init(htmlUrl: "https://github.com/foo/bar/blob/main/LICENSE")) },
            fetchMetadata: { _, _ in eventLoop.future(.mock) },
            fetchReadme: { _, _ in eventLoop.future(.init(htmlUrl: "https://github.com/foo/bar/blob/main/README.md")) },
            fileManager: .mock,
            getStatusCount: { _, _ in eventLoop.future(100) },
            githubToken: { nil },
            gitlabApiToken: { nil },
            gitlabPipelineToken: { nil },
            gitlabPipelineLimit: { Constants.defaultGitlabPipelineLimit },
            hideStagingBanner: { false },
            random: Double.random,
            reportError: { _, _, _ in eventLoop.future(()) },
            rollbarToken: { nil },
            rollbarLogLevel: { .critical },
            shell: .mock,
            siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" }
        )
    }
}
