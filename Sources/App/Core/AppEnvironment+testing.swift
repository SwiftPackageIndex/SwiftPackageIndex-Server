import Vapor


extension AppEnvironment {
    static let mock: Self = .init(
        fetchMasterPackageList: { _ in
            .just(value: ["https://github.com/finestructure/Gala",
                          "https://github.com/finestructure/SwiftPMLibrary-Server"].urls)
        },
        fetchRepository: { _, _ in .just(value: .mock) },
        githubToken: { ProcessInfo.processInfo.environment["GITHUB_TOKEN"] }
    )

    static let e2eTesting: Self = .init(
        fetchMasterPackageList: { _ in .just(value: testUrls) },
        fetchRepository: { _, pkg in .just(value: .mock(for: pkg)) },
        githubToken: { nil }
    )
}


let testUrls = [
    "https://github.com/jaredmpayne/swiftarg.git",
    "https://github.com/AlwaysRightInstitute/SwiftyExpat.git",
    "https://github.com/yshrkt/Elapse.git",
    "https://github.com/slash-hq/slash.git",
    "https://github.com/woxtu/RouteKit.git",
    "https://github.com/hedviginsurance/swiftgraphqlserver.git",
    "https://github.com/elegantchaos/JSONDump.git",
    "https://github.com/googleapis/google-auth-library-swift.git",
    "https://github.com/shaps80/composed.git",
    "https://github.com/backslash-f/Worker.git",
    "https://github.com/ApolloZhu/srt2bilibilikit.git",
    "https://github.com/chrisamanse/QRSwift.git",
    "https://github.com/stefanrenne/SwiftErrorHandler.git",
    "https://github.com/swiftgen/swiftgen.git",
    "https://github.com/perfectlysoft/perfect-notifications.git",
    "https://github.com/project-polyglot/xml.git",
    "https://github.com/persistx/schemata.git",
    "https://github.com/mtynior/ColorizeSwift.git",
    "https://github.com/uraimo/ws281x.swift.git",
    "https://github.com/dduan/Pathos.git",
    ].urls


extension Array where Element == String {
    var urls: [URL] { compactMap(URL.init(string:)) }
}


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
              description: "This is package " + package.url.dropFirst("https://github.com/".count),
              forksCount: package.url.count,
              license: .init(key: "mit"),
              stargazersCount: package.url.count + 1,
              parent: nil)
    }
}
