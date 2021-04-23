// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "SPI-Server",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0-rc"),
        .package(url: "https://github.com/JohnSundell/Plot.git", from: "0.7.0"),
        .package(url: "https://github.com/finestructure/Ink.git",
                 .revision("70b901324d794d88019c299feea737ed0aace3cd")),  // TODO: temporary pin for Xcode-12.5 compatibility
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/MrLotU/SwiftPrometheus.git", from: "1.0.0-alpha"),
        .package(name: "SnapshotTesting",
                 url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.7.2"),
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion", from: "0.3.0"),
        .package(url: "https://github.com/handya/OhhAuth.git", from: "1.4.0"),
        .package(name: "libcmark_gfm", url: "https://github.com/KristopherGBaker/libcmark_gfm", from: "0.29.3"),
        .package(name: "SwiftPM",
                 url: "https://github.com/apple/swift-package-manager.git",
                 .revision("swift-DEVELOPMENT-SNAPSHOT-2021-03-09-a"))
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Vapor", package: "vapor"),
            "Plot",
            "Ink",
            "SemanticVersion",
            "ShellOut",
            "SwiftPrometheus",
            "OhhAuth",
            "libcmark_gfm",
            .product(name: "PackageCollectionsModel", package: "SwiftPM")
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
