import Foundation


extension PackageCollection {
    static func generate(name: String,
                         overview: String? = nil,
                         keywords: [String]? = nil,
                         packageURLs: [String],
                         createdAt: Date = Date(),
                         createdBy: Author? = nil) -> PackageCollection {
        // TODO: look up packages from urls
        let packages = [Package]()
        let collection = PackageCollection.init(
            name: name,
            overview: overview,
            keywords: keywords,
            packages: packages,
            createdAt: createdAt,
            createdBy: createdBy)
        return collection
    }
}
