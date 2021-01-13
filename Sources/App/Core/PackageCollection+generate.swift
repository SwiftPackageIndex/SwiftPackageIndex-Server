import Fluent
import Foundation


typealias PackageCollectionModel = JSONPackageCollectionModel.V1
typealias PackageCollection = PackageCollectionModel.Collection


extension PackageCollection {

    static func generate(db: Database,
                         name: String,
                         overview: String? = nil,
                         keywords: [String]? = nil,
                         packageURLs: [String],
                         generatedBy author: Author? = nil) -> EventLoopFuture<PackageCollection> {
        App.Package.query(on: db)
            .with(\.$repositories)
            .with(\.$versions) {
                $0.with(\.$products)
                $0.with(\.$targets)
            }
            .filter(\.$url ~~ packageURLs)
            .all()
            .mapEachCompact { Package.init(package: $0) }
            .map {
                PackageCollection.init(
                    name: name,
                    overview: overview,
                    keywords: keywords,
                    packages: $0,
                    formatVersion: .v1_0,
                    revision: nil,
                    generatedAt: Current.date(),
                    generatedBy: author)
            }
    }

    static func generate(db: Database,
                         name: String,
                         overview: String? = nil,
                         keywords: [String]? = nil,
                         owner: String,
                         generatedBy author: Author? = nil) -> EventLoopFuture<PackageCollection> {
        App.Package.query(on: db)
            .with(\.$repositories)
            .with(\.$versions) {
                $0.with(\.$products)
                $0.with(\.$targets)
            }
            .join(Repository.self, on: \App.Package.$id == \Repository.$package.$id)
            .filter(Repository.self, \.$owner == owner)
            .all()
            .mapEachCompact { Package.init(package: $0) }
            .map {
                PackageCollection.init(
                    name: name,
                    overview: overview,
                    keywords: keywords,
                    packages: $0,
                    formatVersion: .v1_0,
                    revision: nil,
                    generatedAt: Current.date(),
                    generatedBy: author)
            }
    }

}


extension PackageCollection.Package {
    init?(package: App.Package) {
        guard let url = URL(string: package.url) else { return nil }
        self.init(url: url,
                  summary: package.repository?.summary,
                  keywords: nil,
                  versions: package.versions
                    .compactMap(Self.Version.init(version:))
                    .sorted { $0.version > $1.version },
                  readmeURL: package.repository?.readmeUrl.flatMap(URL.init(string:)),
                  license: nil  // TODO: fill in
        )
    }
}


extension PackageCollection.Package.Version {
    init?(version: App.Version) {
        guard let semVer = version.reference?.semVer,
              let packageName = version.packageName,
              let toolsVersion = version.toolsVersion else {
            return nil
        }
        self.init(
            version: "\(semVer)",
            packageName: packageName,
            targets: version.targets
                .map(PackageCollectionModel.Target.init(target:)),
            products: version.products
                .compactMap(PackageCollectionModel.Product.init(product:)),
            toolsVersion: toolsVersion,
            minimumPlatformVersions: version.supportedPlatforms
                .map(PackageCollectionModel.PlatformVersion.init(platform:)),
            verifiedCompatibility: nil, // TODO: fill in
            license: nil // TODO: fill in
        )
    }
}


extension PackageCollectionModel.PlatformVersion {
    init(platform: App.Platform) {
        self.init(name: platform.name.rawValue, version: platform.version)
    }
}


extension PackageCollectionModel.Target {
    init(target: App.Target) {
        self.init(name: target.name, moduleName: nil)
    }
}


extension PackageCollectionModel.Product {
    init?(product: App.Product) {
        guard let type = PackageCollectionModel
                .ProductType(productType: product.type) else {
            return nil
        }
        self.init(name: product.name,
                  type: type,
                  targets: product.targets)
    }
}


extension PackageCollectionModel.ProductType {
    init?(productType: App.Product.`Type`) {
        switch productType {
            case .executable:
                self = .executable
            case .library:  // TODO: wire up detailed data
                self = .library(.automatic)
        }
    }
}
