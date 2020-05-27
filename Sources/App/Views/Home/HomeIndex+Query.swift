import Fluent
import Plot


extension HomeIndex.Model {
    static func query(database: Database) -> EventLoopFuture<Self> {
        let packages = RecentPackage.fetch(on: database).mapEach(makeDatedLink)
        let releases = RecentRelease.fetch(on: database).mapEach(makeDatedLink)
        return packages.and(releases).map(Self.init)
    }
}


extension HomeIndex.Model {
    static func makeLink(_ recent: RecentPackage) -> Link {
        return .init(label: recent.packageName, url: "/packages\(recent.id.uuidString)")
    }

    static func makeLink(_ recent: RecentRelease) -> Link {
        return .init(label: recent.packageName, url: "/packages\(recent.id.uuidString)")
    }

    static func makeDatedLink(_ recent: RecentPackage) -> DatedLink {
        let link = makeLink(recent)
        return .init(date: "\(date: recent.createdAt, relativeTo: Current.date())", link: link)
    }

    static func makeDatedLink(_ recent: RecentRelease) -> DatedLink {
        let link = makeLink(recent)
        return .init(date: "\(date: recent.releasedAt, relativeTo: Current.date())", link: link)
    }
}
