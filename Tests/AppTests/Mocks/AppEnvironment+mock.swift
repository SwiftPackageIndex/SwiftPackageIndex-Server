@testable import App

import Vapor


extension AppEnvironment {
    static let mock: Self = .init(
        date: Date.init,
        fetchMasterPackageList: { _ in
            .just(value: ["https://github.com/finestructure/Gala",
                          "https://github.com/finestructure/SwiftPMLibrary-Server"].asURLs)
        },
        fetchMetadata: { _, _ in .just(value: .mock) },
        fileManager: .mock,
        githubToken: { nil },
        reportError: { _, _, _ in .just(value: ()) },
        rollbarToken: { nil },
        rollbarLogLevel: { .critical },
        shell: .mock,
        siteURL: { Environment.get("SITE_URL") ?? "http://localhost:8080" }
    )
}
