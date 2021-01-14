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
                $0.with(\.$builds)
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
                $0.with(\.$builds)
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
        guard
            let licenseName = package.repository?.license.shortName,
            let licenseURL = package.repository?.licenseUrl
              .flatMap(URL.init(string:)),
            let url = URL(string: package.url) else { return nil }
        self.init(url: url,
                  summary: package.repository?.summary,
                  keywords: nil,
                  versions: package.versions
                    .compactMap {
                        Self.Version.init(version: $0,
                                          licenseName: licenseName,
                                          licenseURL: licenseURL)
                    }
                    .sorted { $0.version > $1.version },
                  readmeURL: package.repository?.readmeUrl.flatMap(URL.init(string:)),
                  license: .init(name: licenseName, url: licenseURL)
        )
    }
}


extension PackageCollection.Package.Version {
    init?(version: App.Version, licenseName: String, licenseURL: URL) {
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
            verifiedCompatibility: .init(builds: version.builds),
            license: .init(name: licenseName, url: licenseURL)
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


private extension Array where Element == PackageCollectionModel.Compatibility {
    // Helper struct to work around Compatibility not being Hashable
    struct Pair: Hashable {
        var platform: PackageCollectionModel.Platform
        var version: String
    }

    init(builds: [Build]) {
        self.init(
            // Gather up build via a Set to de-duplicate various
            // macOS build variants - spm, xcodebuild, ARM
            Set<Pair>(
                builds.map { Pair.init(platform: .init(platform: $0.platform),
                                       version: $0.swiftVersion.displayName)}
            )
            .map { Element.init(platform: $0.platform, swiftVersion: $0.version) }
            .sorted()
        )
    }
}


extension PackageCollectionModel.Platform {
    init(platform: Build.Platform) {
        switch platform {
            case .ios, .tvos, .watchos, .linux:
                self.init(name: platform.rawValue)
            case .macosSpmArm, .macosXcodebuildArm, .macosSpm, .macosXcodebuild:
                self.init(name: "macos")
        }
    }
}


extension PackageCollectionModel.Platform: Hashable {
    public var hashValue: Int { name.hashValue }
    public func hash(into hasher: inout Hasher) {
        name.hash(into: &hasher)
    }
}


extension PackageCollectionModel.Platform: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.name < rhs.name
    }
}


extension PackageCollectionModel.Compatibility: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.platform != rhs.platform { return lhs.platform < rhs.platform }
        return lhs.swiftVersion < rhs.swiftVersion
    }
}
