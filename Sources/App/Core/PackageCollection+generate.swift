import Fluent
import Foundation


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
            .mapEach { Package.init(package: $0) }
            .map {
                PackageCollection.init(
                    name: name,
                    overview: overview,
                    keywords: keywords,
                    packages: $0,
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
            .mapEach { Package.init(package: $0) }
            .map {
                PackageCollection.init(
                    name: name,
                    overview: overview,
                    keywords: keywords,
                    packages: $0,
                    generatedAt: Current.date(),
                    generatedBy: author)
            }
    }

}


extension PackageCollection.Package {

    init(package: App.Package) {
        self.init(url: package.url,
                  summary: package.repository?.summary,
                  keywords: nil,
                  versions: package.versions
                    .compactMap { version in
                        guard let semVer = version.reference?.semVer,
                              let packageName = version.packageName else {
                            return nil
                        }
                        return PackageCollection.Version.init(
                            version: "\(semVer)",
                            packageName: packageName,
                            products: version.products.compactMap(PackageCollection.Product.init(product:)),
                            targets: version.targets.map(PackageCollection.Target.init(target:))
                        )
                    }
                    .sorted { $0.version > $1.version },
                  readmeURL: package.repository?.readmeUrl
        )
    }

}


extension PackageCollection.Target {

    init(target: App.Target) {
        self.init(name: target.name, moduleName: nil)
    }

}


extension PackageCollection.Product {

    init?(product: App.Product) {
        guard let type = ProductType(rawValue: product.type.rawValue) else {
            return nil
        }
        self.init(name: product.name,
                  type: type,
                  targets: product.targets)
    }

}
