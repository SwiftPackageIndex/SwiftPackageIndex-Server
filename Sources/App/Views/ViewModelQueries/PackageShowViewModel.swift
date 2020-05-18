import Fluent
import Foundation
import Vapor


extension PackageShowView.Model {
    static func query(database: Database, packageId: Package.Id) -> EventLoopFuture<Self> {
        Package.query(on: database)
            .with(\.$repositories)
            .with(\.$versions) { $0.with(\.$products) }
            .filter(\.$id == packageId)
            .first()
            .unwrap(or: Abort(.notFound))
            .map { p in
                // TODO: consider which missing values take defaults and which ones error out
                // Or do we make view model fields optional and let display deal with it?
                // If for instance we have just a package entry with no repository, we should
                // probably error out (because too many fields would be blank).
                Self.init(title: p.name ?? "–",
                          url: p.url,
                          license: p.repository?.license ?? .none,
                          summary: p.repository?.summary ?? "–",
                          authors: [],
                          history: nil,
                          activity: nil,
                          products: p.productCounts)
        }
    }
}


private extension Package {
    // keep this private, because it requires relationships to be eagerly loaded
    // we do this above but in order to ensure this not being called from elsewhere
    // where this isn't guaranteed, we keep this extension off limits
    var defaultVersion: Version? {
        versions.first(where: { $0.reference?.isBranch ?? false })
    }

    var name: String? { defaultVersion?.packageName }

    var productCounts: PackageShowView.Model.ProductCounts? {
        guard let version = defaultVersion else { return nil }
        return .init(
            libraries: version.products.filter(\.isLibrary).count,
            executables: version.products.filter(\.isExecutable).count
        )
    }
}
