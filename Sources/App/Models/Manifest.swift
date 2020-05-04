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


struct Manifest: Codable, Equatable {
    struct Platform: Codable, Equatable {
        enum Name: String, Codable, Equatable {
            case macos
            case ios
            case tvos
            case watchos
        }
        var platformName: Name
        var version: String
    }
    struct Product: Codable, Equatable {
        var name: String
    }
    var name: String
    var platforms: [Platform]?
    var products: [Product]
    var swiftLanguageVersions: [String]?
}


extension Manifest.Platform: CustomStringConvertible {
    var description: String { "\(platformName)_\(version)" }
}
