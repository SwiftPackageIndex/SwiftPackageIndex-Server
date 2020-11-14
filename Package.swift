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
        .package(url: "https://github.com/JohnSundell/Ink.git",
                 .revision("928ffcfa5edb2f53e3008e95ad2d575821bb1733")),  // TODO: temporary pin for Swift 5.3/Linux compatibility
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(url: "https://github.com/MrLotU/SwiftPrometheus.git", from: "1.0.0-alpha"),
        .package(name: "SnapshotTesting",
                 url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.7.2"),
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion", from: "0.3.0"),
        .package(url: "https://github.com/handya/TwitterVapor.git", from: "1.1.0"),
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
            "TwitterVapor",
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
