@testable import App

import Foundation


extension AppEnvironment {
    static let mock: Self = .init(
        date: Date.init,
        fetchMasterPackageList: { _ in
            .just(value: ["https://github.com/finestructure/Gala",
                          "https://github.com/finestructure/SwiftPMLibrary-Server"].urls)
        },
        fetchMetadata: { _, _ in .just(value: .mock) },
        fileManager: .mock,
        githubToken: { nil },
        reportError: { _, _, _ in .just(value: ()) },
        rollbarToken: { nil },
        shell: .mock
    )
}
