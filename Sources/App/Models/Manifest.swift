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
//
// For valid platform values, refer to
// https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/SupportedPlatforms.swift


struct Manifest: Decodable, Equatable {
    struct Platform: Decodable, Equatable {
        enum Name: String, Decodable, Equatable, CaseIterable {
            case custom       // from 5.6
            case driverkit    // from 5.5
            case macos
            case maccatalyst  // from 5.5
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
        case plugin
        case test

        enum CodingKeys: CodingKey {
            case executable
            case library
            case plugin
            case test
        }
    }

    struct Product: Decodable, Equatable {
        var name: String
        var targets: [String] = []
        var type: ProductType
    }

    enum TargetType: String, Equatable, Codable {
        case regular
        case executable
        case test
        case system
        case binary
        case plugin
    }

    struct Target: Decodable, Equatable {
        var name: String
        var type: TargetType
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
            case .plugin:
                self = .plugin
            case .test:
                self = .test
        }
    }
}
