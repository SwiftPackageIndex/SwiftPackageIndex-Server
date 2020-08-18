// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "SPI-Server",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/JohnSundell/Plot.git", from: "0.7.0"),
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.5.0"),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
        .package(name: "SnapshotTesting",
                 url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.7.2"),
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "JWT", package: "jwt"),
            .product(name: "Vapor", package: "vapor"),
            "Plot",
            "Ink",
            "ShellOut"
        ]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
            "ShellOut",
            "SnapshotTesting"
        ])
    ],
    swiftLanguageVersions: [.v5]
)
