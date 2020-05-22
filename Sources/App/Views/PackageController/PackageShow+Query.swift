import Fluent
import Foundation
import Vapor


extension PackageShow.Model {
    static func query(database: Database, packageId: Package.Id) -> EventLoopFuture<Self> {
        Package.query(on: database)
            .with(\.$repositories)
            .with(\.$versions) { $0.with(\.$products) }
            .filter(\.$id == packageId)
            .first()
            .unwrap(or: Abort(.notFound))
            .map { p -> Self? in
                // we consider certain attributes as essential and return nil (raising .notFound)
                guard let title = p.name else { return nil }
                return Self.init(title: title,
                                 url: p.url,
                                 license: p.repository?.license ?? .none,
                                 summary: p.repository?.summary ?? "–",
                                 authors: [],      // TODO: fill in
                                 history: nil,     // TODO: fill in
                                 activity: nil,    // TODO: fill in
                                 products: p.productCounts,
                                 releases: .init(stable: nil, beta: nil, latest: nil),  // TODO: fill in
                                 languagePlatforms: .init(
                                    stable: .init(
                                        link: .init(name: "stable", url: "stable"),  // TODO: fill in
                                        swiftVersions: [],                           // TODO: fill in
                                        platforms: []),                              // TODO: fill in
                                    beta: .init(
                                        link: .init(name: "beta", url: "beta"),      // TODO: fill in
                                        swiftVersions: [],                           // TODO: fill in
                                        platforms: []),                              // TODO: fill in
                                    latest: .init(
                                        link: .init(name: "latest", url: "latest"),  // TODO: fill in
                                        swiftVersions: [],                           // TODO: fill in
                                        platforms: [])))                             // TODO: fill in
            }
            .unwrap(or: Abort(.notFound))
    }
}


extension Package {
    var defaultVersion: Version? {
        guard
            let versions = $versions.value,
            let repositories = $repositories.value,
            let repo = repositories.first,
            let defaultBranch = repo.defaultBranch
            else { return nil }
        return versions.first(where: { v in
            guard let ref = v.reference else { return false }
            switch ref {
                case .branch(let b) where b == defaultBranch:
                    return true
                default:
                    return false
            }
        })
    }

    var name: String? { defaultVersion?.packageName }

    var productCounts: PackageShow.Model.ProductCounts? {
        guard let version = defaultVersion else { return nil }
        return .init(
            libraries: version.products.filter(\.isLibrary).count,
            executables: version.products.filter(\.isExecutable).count
        )
    }
}
