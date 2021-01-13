import struct Foundation.Date

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
//        var latestVersion: Version?
//        var watchersCount: Int?
        var readmeURL: String?
//        var authors: [Author]?
    }
}

extension PackageCollection {
    struct Version: Equatable, Codable {
        var version: String
        var packageName: String
        var products: [Product]
        var targets: [Target]
        var toolsVersion: String
        var minimumPlatformVersions: [SupportedPlatform]?
        var verifiedPlatforms: [Platform]?
        var verifiedSwiftVersion: [String]?
        var license: License?
    }
}

extension PackageCollection {
    struct License: Equatable, Codable {
        var name: String
        var url: String
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

extension PackageCollection {
    enum Platform: String, Codable {
        case macos
        case ios
        case tvos
        case watchos
        case linux
        case android
        case windows
        case wasi
    }
}

extension PackageCollection {
    struct SupportedPlatform: Equatable, Codable {
        public let platform: Platform
        public let version: String
        public let options: [String]

        public init(platform: Platform, version: String, options: [String] = []) {
            self.platform = platform
            self.version = version
            self.options = options
        }
    }
}
