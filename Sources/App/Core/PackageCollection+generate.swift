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

import Dependencies
import Fluent
import PackageCollectionsModel


typealias PackageCollection = PackageCollectionModel.V1.Collection


extension PackageCollection {
    typealias Compatibility = PackageCollectionModel.V1.Compatibility
    typealias License = PackageCollectionModel.V1.License
    typealias Platform = PackageCollectionModel.V1.Platform
    typealias PlatformVersion = PackageCollectionModel.V1.PlatformVersion
    typealias Product = PackageCollectionModel.V1.Product
    typealias ProductType = PackageCollectionModel.V1.ProductType
    typealias Target = PackageCollectionModel.V1.Target

    enum Filter {
        case urls([String])
        case author(String)
        case keyword(String)
        case customCollection(String)
    }

    enum Error: Swift.Error {
        case noResults
    }

    static func generate(db: Database,
                         filterBy filter: Filter,
                         authorName: String? = nil,
                         collectionName: String? = nil,
                         keywords: [String]? = nil,
                         overview: String? = nil,
                         revision: Int? = nil,
                         limit maxResults: Int? = nil) async throws -> PackageCollection {
        let results = try await VersionResult.query(on: db, filterBy: filter, limit: maxResults)

        // Multiple versions can reference the same package, therefore
        // we need to group them so we don't create duplicate packages.
        let groups = results.groupedByPackage(sortBy: .url)

        let packages = groups.compactMap { Package.init(resultGroup: $0, keywords: keywords) }
        let authorLabel = authorLabel(repositories: groups.map(\.repository))
        let collectionName = collectionName ?? Self.collectionName(for: filter, authorLabel: authorLabel)
        let overview = overview ?? Self.overview(for: filter, authorLabel: authorLabel)

        guard !packages.isEmpty else { throw Error.noResults }

        @Dependency(\.date.now) var now

        return PackageCollection.init(
            name: collectionName,
            overview: overview,
            keywords: keywords,
            packages: packages,
            formatVersion: .v1_0,
            revision: revision,
            generatedAt: now,
            generatedBy: authorName.map(Author.init(name:))
        )
    }

    static func authorLabel(repositories: [Repository]) -> String? {
        let names = Set(
            repositories.compactMap { $0.ownerName ?? $0.owner }
        ).sorted()
        switch names.count {
            case 0:
                // shouldn't be possible really
                return nil
            case 1:
                return names.first!
            case 2:
                return names.joined(separator: " and ")
            default:
                return "multiple authors"
        }
    }

    static func author(for filter: Filter, authorLabel: String?) -> String {
        switch (filter, authorLabel) {
            case (.author(let owner), .none):
                return owner
            case (.author, .some(let label)):
                return label
            case (.keyword(let keyword), .none):
                return keyword
            case (.keyword, .some(let label)):
                return label
            case (.customCollection(let name), .none):
                return name
            case (.customCollection, .some(let label)):
                return label
            case (.urls(let urls), .none):
                return author(for: urls)
            case (.urls, .some(let label)):
                return label
        }
    }

    static func author(for urls: [String]) -> String {
        let owners = urls.compactMap { try? Github.parseOwnerName(url: $0).owner }
        switch owners.count {
            case 0:
                return "unknown author"
            case 1:
                return owners.first!
            case 2:
                return owners.joined(separator: " ")
            default:
                return "multiple authors"
        }
    }

    static func collectionName(for filter: Filter, authorLabel: String?) -> String {
        "Packages by \(author(for: filter, authorLabel: authorLabel))"
    }

    static func overview(for filter: Filter, authorLabel: String?) -> String {
        "A collection of packages authored by \(author(for: filter, authorLabel: authorLabel)) from the Swift Package Index"
    }
}


// MARK: - Initializers to transform SPI entities to Package Collection Model entities


extension PackageCollection.Package {

    /// Create a PackageCollections.Package from an App.Package (a database record, essentially).
    /// Note that we pass in an array of "pruned" `Version`s instead of using `package.versions`, because the latter would add *all* versions to the package collection, negating the filtering we've done to only include `release` and `preRelease` versions.
    /// - Parameters:
    ///   - version: `VersionResult`
    ///   - prunedVersions: filtered array of this package's versions to include in the collection
    ///   - keywords: array of keywords to include in the collection
    init?(resultGroup: PackageCollection.VersionResultGroup,
          keywords: [String]?) {
        let repository = resultGroup.repository
        let license = PackageCollection.License(
            name: repository.license.shortName,
            url: repository.licenseUrl
        )

        let versions = resultGroup.versions.compactMap {
            Version(version: $0, license: license)
        }.sorted { $0.version > $1.version }

        guard let url = URL(string: resultGroup.package.url),
              !versions.isEmpty
        else { return nil }

        self.init(
            url: url,
            summary: repository.summary,
            keywords: keywords,
            versions: versions,
            readmeURL: repository.readmeHtmlUrl.flatMap(URL.init(string:)),
            license: license
        )
    }

}


extension PackageCollection.Package.Version {
    init?(version: App.Version, license: PackageCollection.License?) {
        let products = version.products
            .compactMap(PackageCollection.Product.init(product:))
        guard
            let semVer = version.reference.semVer,
            let packageName = version.packageName,
            let toolsVersion = version.toolsVersion,
            !products.isEmpty
        else { return nil }

        let manifest = Manifest(
            toolsVersion: toolsVersion,
            packageName: packageName,
            targets: version.targets.map(PackageCollection.Target.init(target:)),
            products: products,
            minimumPlatformVersions: version.supportedPlatforms
                .map(PackageCollection.PlatformVersion.init(platform:))
        )

        self.init(
            version: "\(semVer)",
            summary: version.releaseNotes,
            manifests: [toolsVersion: manifest],
            defaultToolsVersion: toolsVersion,
            verifiedCompatibility: .init(builds: version.builds),
            license: license,
            author: nil,
            signer: .spi,
            createdAt: version.publishedAt
        )
    }
}


extension PackageCollection.License {
    init?(name: String?, url: String?) {
        guard let url = url.flatMap(URL.init(string:)) else { return nil }
        self.init(name: name, url: url)
    }
}


extension PackageCollection.PlatformVersion {
    init(platform: App.Platform) {
        self.init(name: platform.name.rawValue, version: platform.version)
    }
}


private extension PackageCollection.Target {
    init(target: App.Target) {
        self.init(name: target.name,
                  moduleName: target.name.spm_mangledToC99ExtendedIdentifier())
    }
}


private extension PackageCollection.Product {
    init?(product: App.Product) {
        guard let type = product.type
                .flatMap(PackageCollection.ProductType.init(productType:))
        else { return nil }
        self.init(name: product.name,
                  type: type,
                  targets: product.targets)
    }
}


private extension PackageCollection.ProductType {
    init?(productType: App.ProductType) {
        switch productType {
            case .executable:
                self = .executable
            case .library(.automatic):
                self = .library(.automatic)
            case .library(.dynamic):
                self = .library(.dynamic)
            case .library(.static):
                self = .library(.static)
            case .test:
                self = .test
            case .plugin:
                self = .plugin
        }
    }
}


extension Array where Element == PackageCollection.Compatibility {
    // Helper struct to work around Compatibility not being Hashable
    struct Pair: Hashable {
        var platform: PackageCollection.Platform
        var version: String
    }

    init(builds: [Build]) {
        self.init(
            // Gather up builds via a Set to de-duplicate various
            // macOS build variants - spm, xcodebuild, ARM
            Set<Pair>(
                builds
                    .filter { $0.status == .ok}
                    .map { Pair.init(platform: .init(platform: $0.platform),
                                     version: $0.swiftVersion.displayName) }
            )
            .map { Element.init(platform: $0.platform, swiftVersion: $0.version) }
            .sorted()
        )
    }
}


private extension PackageCollection.Platform {
    init(platform: Build.Platform) {
        switch platform {
            case .iOS, .tvOS, .visionOS, .watchOS, .linux:
                self.init(name: platform.rawValue)
            case .macosSpm, .macosXcodebuild:
                self.init(name: "macos")
        }
    }
}


extension PackageCollectionModel.V1.Signer {
    static var spi: Self {
        .init(type: "ADP",
              commonName: "Swift Package Index",
              organizationalUnitName: "Swift Package Index",
              organizationName: "Swift Package Index")
    }
}
