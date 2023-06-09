// swift-tools-version:5.8

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
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.5.1"),
        .package(url: "https://github.com/JohnSundell/Plot.git", from: "0.10.0"),
        .package(url: "https://github.com/MrLotU/SwiftPrometheus.git", from: "1.0.0-alpha"),
        .package(url: "https://github.com/SwiftPackageIndex/DependencyResolution", from: "1.0.0"),
        .package(url: "https://github.com/SwiftPackageIndex/SPIManifest", from: "0.17.0"),
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion", from: "0.3.0"),
        .package(url: "https://github.com/SwiftPackageIndex/ShellOut.git",
                 revision: "db112a2104eae7fa8412ea80210d0f60b89a377e"),
        .package(url: "https://github.com/apple/swift-package-manager.git", branch: "release/5.8"),
        // FIXME: unpin when build error is fixed https://github.com/dankinsoid/SwiftOpenAPI/issues/3
        .package(url: "https://github.com/dankinsoid/SwiftOpenAPI.git", exact: "2.16.6"),
        .package(url: "https://github.com/dankinsoid/VaporToOpenAPI.git", from: "3.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.12.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.7.2"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.2"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", exact: "2.6.2"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(name: "Run", dependencies: ["App"]),
        .target(name: "App", dependencies: [
            "Ink",
            "Plot",
            "SPIManifest",
            "SemanticVersion",
            "SwiftPrometheus",
            "SwiftSoup",
            .product(name: "CustomDump", package: "swift-custom-dump"),
            .product(name: "DependencyResolution", package: "DependencyResolution"),
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
            .product(name: "Parsing", package: "swift-parsing"),
            .product(name: "ShellOut", package: "ShellOut"),
            .product(name: "VaporToOpenAPI", package: "VaporToOpenAPI"),
            .product(name: "SwiftPMPackageCollections", package: "swift-package-manager"),
            .product(name: "Vapor", package: "vapor"),
        ]),
        .testTarget(name: "AppTests",
            dependencies: [
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "XCTVapor", package: "vapor"),
                .target(name: "App"),
            ],
            exclude: ["__Snapshots__", "Fixtures"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
