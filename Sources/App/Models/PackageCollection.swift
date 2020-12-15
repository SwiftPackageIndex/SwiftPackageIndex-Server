import struct Foundation.Date
import SemanticVersion

// https://github.com/apple/swift-package-collection-generator/blob/main/PackageCollectionFormats/v1.md

struct PackageCollection: Equatable, Codable {
    var name: String
    var overview: String?
    var keywords: [String]?
    var packages: [Package]
    var createdAt: Date
    var createdBy: Author?
}

extension PackageCollection {
    struct Package: Equatable, Codable {
        var url: String
        var summary: String?
        var keywords: [String]?
        var readmeURL: String?
        var versions: [Version]
    }
}

extension PackageCollection {
    struct Version: Equatable, Codable {
        var version: SemanticVersion
        var packageName: String
        var targets: [Target]
        var products: [Product]
    }
}

extension PackageCollection {
    struct Target: Equatable, Codable {
        var name: String
        var moduleName: String?
    }
}

extension PackageCollection {
    struct Product: Equatable, Codable {
        var name: String
        var type: Type
        var target: [Target]

        enum `Type`: String, Equatable, Codable {
            case executable
            case library
        }
    }
}
