import Fluent
import Foundation


extension PackageCollection {
    static func generate(db: Database,
                         name: String,
                         overview: String? = nil,
                         keywords: [String]? = nil,
                         packageURLs: [String],
                         createdBy: Author? = nil) -> EventLoopFuture<PackageCollection> {
        App.Package.query(on: db)
            .with(\.$repositories)
            .filter(\.$url ~~ packageURLs)
            .all()
            .mapEach { dbPackage in
                Package.init(url: dbPackage.url,
                             summary: dbPackage.repository?.summary,
                             keywords: nil,
                             readmeURL: nil,
                             versions: [])
            }
            .map { packages in
                PackageCollection.init(
                    name: name,
                    overview: overview,
                    keywords: keywords,
                    packages: packages,
                    createdAt: Date(),
                    createdBy: createdBy)
            }
    }

    static func generate(db: Database,
                         name: String,
                         overview: String? = nil,
                         keywords: [String]? = nil,
                         owner: String,
                         createdBy: Author? = nil) -> EventLoopFuture<PackageCollection> {
        Repository.query(on: db)
            .with(\.$package) {
                $0.with(\.$versions) {
                    $0.with(\.$products)
                }
            }
            .filter(\.$owner == owner)
            .all()
            .mapEach { repository in
                Package.init(url: repository.package.url,
                             summary: repository.summary,
                             keywords: nil,
                             readmeURL: nil,
                             versions: repository.package.versions
                                .compactMap { dbVersion in
                                    guard let semVer = dbVersion.reference?.semVer,
                                          let packageName = dbVersion.packageName else {
                                        return nil
                                    }
                                    return Version.init(
                                        version: semVer,
                                        packageName: packageName,
                                        targets: [],  // FIXME
                                        products: []  // FIXME
                                    )
                                }
                                .sorted { $0.version > $1.version }
                )
            }
            .map { packages in
                PackageCollection.init(
                    name: name,
                    overview: overview,
                    keywords: keywords,
                    packages: packages,
                    createdAt: Date(),
                    createdBy: createdBy)
            }
    }
}
