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
                                 releases: p.releaseInfo,
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

    var releaseInfo: PackageShow.Model.ReleaseInfo {
        let versions = $versions.value ?? []

        let releases = versions
            .filter { $0.reference?.semVer != nil }
            .sorted { $0.reference!.semVer! < $1.reference!.semVer! }
        let stable = releases.reversed().first { $0.reference?.semVer?.isStable ?? false }
        let beta = releases.reversed().first { $0.reference?.semVer?.isPrerelease ?? false }
        let latest = defaultVersion

        return .init(stable: stable.flatMap { makeDatedLink($0, \.commitDate) },
                     beta: beta.flatMap { makeDatedLink($0, \.commitDate) },
                     latest: latest.flatMap { makeDatedLink($0, \.commitDate) })
    }

    func makeDatedLink(_ version: Version,
                       _ keyPath: KeyPath<Version, Date?>) -> PackageShow.Model.DatedLink? {
        guard
            let date = version[keyPath: keyPath],
            let link = makeLink(version)
            else { return nil }
        let formatter = RelativeDateTimeFormatter()
        return .init(date: formatter.localizedString(for: date, relativeTo: Current.date()),
                     link: link)
    }

    func makeLink(_ version: Version) -> PackageShow.Model.Link? {
        guard
            // FIXME: test eager loading resolution
            let fault = version.$reference.value,
            let ref = fault
            else { return nil }
        let linkUrl: String
        switch ref {
            case .branch:
                linkUrl = url
            case .tag(let v):
                linkUrl = url.droppingGitExtension + "/releases/tag/\(v)"
        }
        return .init(name: "\(ref)", url: linkUrl)
    }

}
