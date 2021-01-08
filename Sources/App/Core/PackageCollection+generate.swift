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
                    generatedAt: Date(),
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
                    .compactMap { dbVersion in
                        guard let semVer = dbVersion.reference?.semVer,
                              let packageName = dbVersion.packageName else {
                            return nil
                        }
                        return PackageCollection.Version.init(
                            version: "\(semVer)",
                            packageName: packageName,
                            targets: [],  // FIXME
                            products: []  // FIXME
                        )
                    }
                    .sorted { $0.version > $1.version },
                  readmeURL: nil
        )
    }

}
