import Fluent
import Foundation
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
    }

    static func generate(db: Database,
                         filterBy filter: Filter,
                         authorName: String? = nil,
                         collectionName: String? = nil,
                         keywords: [String]? = nil,
                         overview: String? = nil,
                         revision: Int? = nil) -> EventLoopFuture<PackageCollection> {
        var query = App.Version.query(on: db)
            .with(\.$builds)
            .with(\.$products)
            .with(\.$targets)
            .with(\.$package) {
                $0.with(\.$repositories)
            }
            .join(App.Package.self, on: \App.Package.$id == \Version.$package.$id)
            .join(Repository.self, on: \App.Package.$id == \Repository.$package.$id)
            .filter(Version.self, \.$latest ~~ [.release, .preRelease])
        
        switch filter {
            case let .author(owner):
                query = query
                    .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            case let .urls(packageURLs):
                query = query
                    .filter(App.Package.self, \.$url ~~ packageURLs)
        }

        return query.all()
            .map { versions in
                // Multiple versions can reference the same package, therefore
                // we need to group them so we don't create duplicate packages.
                // This requires App.Package to be Hashable and Equatable.
                Dictionary(grouping: versions, by: { $0.package })
                    .sorted(by: { $0.key.url < $1.key.url })
            }
            .map { packageToVersions in
                let packages = packageToVersions.compactMap {
                    Package.init(package: $0.key,
                                 prunedVersions: $0.value,
                                 keywords: keywords) }
                let authorLabel = authorLabel(packages: packageToVersions.map(\.key))
                let collectionName = collectionName ?? Self.collectionName(for: filter, authorLabel: authorLabel)
                let overview = overview ?? Self.overview(for: filter, authorLabel: authorLabel)
                return (packages, collectionName, overview)
            }
            .map { (packages: [Package],
                    collectionName: String,
                    overview: String) -> PackageCollection in
                PackageCollection.init(
                    name: collectionName,
                    overview: overview,
                    keywords: keywords,
                    packages: packages,
                    formatVersion: .v1_0,
                    revision: revision,
                    generatedAt: Current.date(),
                    generatedBy: authorName.map(Author.init(name:)))
            }
    }

    static func authorLabel(packages: [App.Package]) -> String? {
        let groupedPackagesByName = Dictionary(
            grouping: packages,
            by: { $0.repository?.ownerName ?? $0.repository?.owner }
        )

        let names = groupedPackagesByName.enumerated().compactMap(\.element.key)
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
            case (.urls, .some(let label)):
                return label
            case (.urls(let urls), .none):
                return author(for: urls)
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
    ///   - package: package model
    ///   - prunedVersions: filtered array of this package's versions to include in the collection
    ///   - keywords: array of keywords to include in the collection
    init?(package: App.Package,
          prunedVersions: [App.Version],
          keywords: [String]?) {
        let license = PackageCollection.License(
            name: package.repository?.license.shortName,
            url: package.repository?.licenseUrl
        )

        let versions = [Version].init(versions: prunedVersions,
                                      license: license)

        guard let url = URL(string: package.url),
              !versions.isEmpty
        else { return nil }

        self.init(
            url: url,
            summary: package.repository?.summary,
            keywords: keywords,
            versions: versions,
            readmeURL: package.repository?.readmeUrl.flatMap(URL.init(string:)),
            license: license
        )
    }

}


extension PackageCollection.Package.Version {
    init?(version: App.Version, license: PackageCollection.License?) {
        let products = version.products
            .compactMap(PackageCollection.Product.init(product:))
        guard
            let semVer = version.reference?.semVer,
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
            createdAt: version.publishedAt
        )
    }
}


private extension Array where Element == PackageCollection.Package.Version {
    init(versions: [App.Version], license: PackageCollection.License?) {
        self.init(
            versions.compactMap {
                Element.init(version: $0, license: license)
            }
            .sorted { $0.version > $1.version }
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
        }
    }
}


private extension Array where Element == PackageCollection.Compatibility {
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
                builds.map { Pair.init(platform: .init(platform: $0.platform),
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
            case .ios, .tvos, .watchos, .linux:
                self.init(name: platform.rawValue)
            case .macosSpmArm, .macosXcodebuildArm, .macosSpm, .macosXcodebuild:
                self.init(name: "macos")
        }
    }
}
