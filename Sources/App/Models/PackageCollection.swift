import struct Foundation.Date
import SemanticVersion

// https://github.com/apple/swift-package-collection-generator/blob/main/PackageCollectionFormats/v1.md

struct PackageCollection: Equatable, Codable {
    var name: String
    var overview: String?
    var keywords: [String]?
    var packages: [Package]
    var formatVersion: FormatVersion = .v1_0
    var revision: Int?
    var generatedAt: Date
    var generatedBy: Author?
}

extension PackageCollection {
    enum FormatVersion: String, Equatable, Codable {
        case v1_0 = "1.0"
    }
}

extension PackageCollection {
    struct Package: Equatable, Codable {
        var url: String
        var summary: String?
        var keywords: [String]?
        var versions: [Version]
        var readmeURL: String?
    }
}

extension PackageCollection {
    struct Version: Equatable, Codable {
        var version: String
        var packageName: String
        var products: [Product]
        var targets: [Target]
        // var toolsVersion: String
        // var minimumPlatformVersions: [PlatformVersion]
        // var verifiedPlatforms: [Platform]
        // var verifiedSwiftVersion: [String]?
        // var license: License?
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
        var type: ProductType
        var targets: [String]

        enum ProductType: String, Equatable, Codable {
            case executable
            case library  //(LibraryType)
        }

        //    enum LibraryType: String, Equatable, Codable {
        //        case `static`
        //        case `dynamic`
        //        case automatic
        //    }
    }
}
