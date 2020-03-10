// swift-tools-version:4.0
import PackageDescription

let package = Package(
  name: "SwiftPackageIndex",
  products: [
    .library(name: "SwiftPackageIndex", targets: ["App"]),
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
    .package(url: "https://github.com/vapor/fluent-sqlite.git", from: "3.0.0")
  ],
  targets: [
    .target(name: "App", dependencies: ["FluentSQLite", "Vapor"]),
    .target(name: "Run", dependencies: ["App"]),
    .testTarget(name: "AppTests", dependencies: ["App"])
  ]
)
