import Foundation


// `Manifest` is mirroring what `dump-package` presumably renders into JSON
// https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html
// Mentioning this in particular with regards to optional values, like `platforms`
// vs mandatory ones like `products`
//
//Package(
//    name: String,
//    platforms: [SupportedPlatform]? = nil,
//    products: [Product] = [],
//    dependencies: [Package.Dependency] = [],
//    targets: [Target] = [],
//    swiftLanguageVersions: [SwiftVersion]? = nil,
//    cLanguageStandard: CLanguageStandard? = nil,
//    cxxLanguageStandard: CXXLanguageStandard? = nil
//)


struct Manifest: Decodable, Equatable {
    struct Platform: Decodable, Equatable {
        enum Name: String, Decodable, Equatable, CaseIterable {
            case macos
            case ios
            case tvos
            case watchos
        }
        var platformName: Name
        var version: String
    }

    enum LibraryType: String, Decodable {
        case automatic
        case `dynamic`
        case `static`
    }

    enum ProductType: Equatable {
        case executable
        case library(LibraryType)
        case test

        enum CodingKeys: CodingKey {
            case executable
            case library
            case test
        }
    }

    struct Product: Decodable, Equatable {
        var name: String
        var targets: [String] = []
        var type: ProductType
    }

    struct Target: Decodable, Equatable {
        var name: String
    }

    struct ToolsVersion: Decodable, Equatable {
        enum CodingKeys: String, CodingKey {
            case version = "_version"
        }
        var version: String
    }

    var name: String
    var platforms: [Platform]?
    var products: [Product]
    var swiftLanguageVersions: [String]?
    var targets: [Target]
    var toolsVersion: ToolsVersion?
}


extension Manifest.ProductType: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let key = container.allKeys.first(where: container.contains) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Did not find a matching key"))
        }
        switch key {
            case .executable:
                self = .executable
            case .library:
                var unkeyedValues = try container.nestedUnkeyedContainer(forKey: key)
                let value = try unkeyedValues.decode(Manifest.LibraryType.self)
                self = .library(value)
            case .test:
                self = .test
        }
    }
}
