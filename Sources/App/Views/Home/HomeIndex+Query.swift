import Fluent
import Plot


extension HomeIndex.Model {
    static func query(database: Database) -> EventLoopFuture<Self> {
        let stats = Stats.fetch(on: database)
        let packages = RecentPackage.fetch(on: database).mapEach(makeDatedLink)
        let releases = RecentRelease.fetch(on: database).mapEach(Release.init(recent:))
        return stats.and(packages).and(releases)
            .map { ($0.0, $0.1, $1) }
            .map(Self.init)
    }
}


extension HomeIndex.Model {
    static func makeLink(_ recent: RecentPackage) -> Link {
        return .init(label: recent.packageName,
                     url: SiteURL.package(.value(recent.repositoryOwner),
                                          .value(recent.repositoryName)).relativeURL())
    }
    
    static func makeDatedLink(_ recent: RecentPackage) -> DatedLink {
        let link = makeLink(recent)
        return .init(date: "\(date: recent.createdAt, relativeTo: Current.date())", link: link)
    }
}


extension HomeIndex.Model.Release {
    init(recent: RecentRelease) {
        packageName = recent.packageName
        version = recent.version
        date = "\(date: recent.releasedAt, relativeTo: Current.date())"
        url = SiteURL.package(.value(recent.repositoryOwner),
                              .value(recent.repositoryName)).relativeURL()
    }
}
