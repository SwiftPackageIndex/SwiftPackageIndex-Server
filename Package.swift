// swift-tools-version:6.0

// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PackageDescription

let package = Package(
    name: "SPI-Server",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "Authentication", targets: ["Authentication"]),
        .library(name: "S3Store", targets: ["S3Store"]),
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.5.1"),
        .package(url: "https://github.com/swift-server/swift-prometheus.git", from: "1.0.0"),
        .package(url: "https://github.com/SwiftPackageIndex/Plot.git", branch: "main"),
        .package(url: "https://github.com/SwiftPackageIndex/CanonicalPackageURL.git", from: "0.0.8"),
        .package(url: "https://github.com/SwiftPackageIndex/DependencyResolution.git", from: "1.1.2"),
        .package(url: "https://github.com/SwiftPackageIndex/SPIManifest.git", from: "1.2.0"),
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion.git", from: "0.3.0"),
        .package(url: "https://github.com/SwiftPackageIndex/ShellOut.git", from: "3.1.4"),
        .package(url: "https://github.com/swiftlang/swift-package-manager.git", branch: "release/5.10"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.11.1"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.2"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.0.0"),
        .package(url: "https://github.com/vapor-community/soto-cognito-authentication.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.13.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.102.0"),
    ],
    targets: [
        .executableTarget(name: "Run", dependencies: ["App"]),
        .target(name: "App",
                dependencies: [
                    .target(name: "Authentication"),
                    .target(name: "S3Store"),
                    .product(name: "Ink", package: "Ink"),
                    .product(name: "Plot", package: "Plot"),
                    .product(name: "SwiftPrometheus", package: "swift-prometheus"),
                    .product(name: "SPIManifest", package: "SPIManifest"),
                    .product(name: "SemanticVersion", package: "SemanticVersion"),
                    .product(name: "SwiftSoup", package: "SwiftSoup"),
                    .product(name: "CanonicalPackageURL", package: "CanonicalPackageURL"),
                    .product(name: "CustomDump", package: "swift-custom-dump"),
                    .product(name: "Dependencies", package: "swift-dependencies"),
                    .product(name: "DependenciesMacros", package: "swift-dependencies"),
                    .product(name: "DependencyResolution", package: "DependencyResolution"),
                    .product(name: "Fluent", package: "fluent"),
                    .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "Redis", package: "redis"),
                    .product(name: "ShellOut", package: "ShellOut"),
                    .product(name: "SwiftPMDataModel-auto", package: "swift-package-manager"),
                    .product(name: "SwiftPMPackageCollections", package: "swift-package-manager"),
                    .product(name: "Vapor", package: "vapor"),
                    .product(name: "SotoCognitoAuthentication", package: "soto-cognito-authentication")
                ],
                swiftSettings: swiftSettings,
                linkerSettings: [.unsafeFlags(["-Xlinker", "-interposable"],
                                              .when(platforms: [.macOS],
                                                    configuration: .debug))]),
        .target(name: "S3Store",
                dependencies: [
                    .product(name: "SotoS3", package: "soto"),
                ],
                swiftSettings: swiftSettings),
        .target(name: "Authentication",
                dependencies: [
                    .product(name: "JWTKit", package: "jwt-kit")
                ],
                swiftSettings: swiftSettings),
        .testTarget(name: "AppTests",
                    dependencies: [
                        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
                        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                        .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
                        .product(name: "XCTVapor", package: "vapor"),
                        .target(name: "App"),
                    ],
                    exclude: ["__Snapshots__", "Fixtures"],
                    swiftSettings: swiftSettings),
        .testTarget(name: "AuthenticationTests",
                    dependencies: [
                        .target(name: "Authentication"),
                    ],
                    swiftSettings: swiftSettings),
        .testTarget(name: "S3StoreTests",
                    dependencies: [
                        .target(name: "S3Store"),
                    ],
                    swiftSettings: swiftSettings)
    ],
    swiftLanguageModes: [.v6]
)

var swiftSettings: [SwiftSetting] { [] }
