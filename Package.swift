// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "SPI-Server",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", .branch("async-await")),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-kit", .branch("async-await")),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-rc"),
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.5.1"),
        .package(url: "https://github.com/JohnSundell/Plot.git", from: "0.10.0"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/MrLotU/SwiftPrometheus.git", from: "1.0.0-alpha"),
        .package(name: "SnapshotTesting",
                 url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.7.2"),
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion", from: "0.3.0"),
        .package(url: "https://github.com/handya/OhhAuth.git", from: "1.4.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.2"),
        .package(name: "SwiftPM",
                 url: "https://github.com/apple/swift-package-manager.git",
                 .revision("swift-DEVELOPMENT-SNAPSHOT-2021-05-04-a"))
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentKit", package: "fluent-kit"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Vapor", package: "vapor"),
            "Plot",
            "Ink",
            "SemanticVersion",
            "ShellOut",
            "SwiftPrometheus",
            "OhhAuth",
            "SwiftSoup",
            .product(name: "PackageCollectionsModel", package: "SwiftPM")
        ],
        swiftSettings: [
            .unsafeFlags([
                "-Xfrontend", "-disable-availability-checking",
                "-Xfrontend", "-enable-experimental-concurrency",
            ])
        ]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
            "SnapshotTesting"
        ])
    ],
    swiftLanguageVersions: [.v5]
)
