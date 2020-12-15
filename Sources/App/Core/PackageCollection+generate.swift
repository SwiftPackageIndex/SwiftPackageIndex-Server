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
}
