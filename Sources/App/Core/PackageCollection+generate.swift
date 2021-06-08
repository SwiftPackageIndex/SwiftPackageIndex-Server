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

    static func generate(db: Database,
                         packageURLs: [String],
                         authorName: String? = nil,
                         collectionName: String,
                         keywords: [String]? = nil,
                         overview: String? = nil,
                         revision: Int? = nil) -> EventLoopFuture<PackageCollection> {
        packageQuery(db: db)
            .filter(\.$url ~~ packageURLs)
            .all()
            .mapEachCompact { Package.init(package:$0, keywords: keywords) }
            .map {
                PackageCollection.init(
                    name: collectionName,
                    overview: overview,
                    keywords: keywords,
                    packages: $0,
                    formatVersion: .v1_0,
                    revision: revision,
                    generatedAt: Current.date(),
                    generatedBy: authorName.map(Author.init(name:)))
            }
    }

    static func generate(db: Database,
                         owner: String,
                         authorName: String? = nil,
                         collectionName: String,
                         keywords: [String]? = nil,
                         overview: String? = nil,
                         revision: Int? = nil) -> EventLoopFuture<PackageCollection> {
        packageQuery(db: db)
            .join(Repository.self, on: \App.Package.$id == \Repository.$package.$id)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner.lowercased())
            .all()
            .mapEachCompact { Package.init(package:$0, keywords: keywords) }
            .map {
                PackageCollection.init(
                    name: collectionName,
                    overview: overview,
                    keywords: keywords,
                    packages: $0,
                    formatVersion: .v1_0,
                    revision: revision,
                    generatedAt: Current.date(),
                    generatedBy: authorName.map(Author.init(name:)))
            }
    }

}


extension PackageCollection {

    private static func packageQuery(db: Database) -> QueryBuilder<App.Package> {
        App.Package.query(on: db)
            .with(\.$repositories)
            .with(\.$versions) {
                $0.with(\.$builds)
                $0.with(\.$products)
                $0.with(\.$targets)
            }
    }

}


// MARK: - Initializers to transform SPI entities to Package Collection Model entities


extension PackageCollection.Package {
    init?(package: App.Package, keywords: [String]?) {
        let license = PackageCollection.License(
            name: package.repository?.license.shortName,
            url: package.repository?.licenseUrl
        )

        let appVersions = package.versions.filter { $0.latest != nil }
        let versions = [Version].init(versions: appVersions, license: license)

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
        self.init(name: target.name, moduleName: nil)
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
