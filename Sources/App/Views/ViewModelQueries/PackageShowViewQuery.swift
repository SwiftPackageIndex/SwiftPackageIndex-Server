import Fluent
import Foundation
import Vapor


// FIXME: fill with query
func mockModel(_ package: Package) -> PackageShowView.Model {
    .init(title: "Alamofire",
          url: "https://github.com/Alamofire/Alamofire.git",
          license: .mit,
          summary: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque quis porttitor erat. Vivamus porttitor mi odio, quis imperdiet velit blandit id. Vivamus vehicula urna eget ipsum laoreet, sed porttitor sapien malesuada. Mauris faucibus tellus at augue vehicula, vitae aliquet felis ullamcorper. Praesent vitae leo rhoncus, egestas elit id, porttitor lacus. Cras ac bibendum mauris. Praesent luctus quis nulla sit amet tempus. Ut pharetra non augue sed pellentesque.",
          authors: [
            .init(name: "Christian Noon", url: "https://github.com/cnoon"),
            .init(name: "Mattt", url: "https://github.com/mattt"),
            .init(name: "Jon Shier", url: "https://github.com/jshier"),
            .init(name: "Kevin Harwood", url: "https://github.com/kcharwood"),
            .init(name: "186 other contributors", url: "https://github.com/Alamofire/Alamofire/graphs/contributors"),
        ],
          history: .init(
            since: "over 5 years",
            commits: .init(name: "1,433 commits",
                           url: "https://github.com/Alamofire/Alamofire/commits/master"),
            releases: .init(name: "79 releases",
                            url: "https://github.com/Alamofire/Alamofire/releases")
        ),
          activity: .init(
            openIssues: .init(name: "27 open issues",
                              url: "https://github.com/Alamofire/Alamofire/issues"),
            pullRequests: .init(name: "5 open pull requests",
                                url: "https://github.com/Alamofire/Alamofire/pulls"),
            lastPullRequestClosedMerged: "6 days ago"),
          products: (libraries: 3, executables: 1)
    )
}


extension PackageShowView.Model {
    static func query(database: Database, packageId: Package.Id) -> EventLoopFuture<Self> {
        Package.query(on: database)
            .with(\.$repositories)
            .with(\.$versions)
            .first()
            .unwrap(or: Abort(.notFound))
            .map { p in
                // TODO: consider which missing values take defaults and which ones error out
                // or make fields optional and let display deal with it?
                Self.init(title: "title",
                          url: p.url,
                          license: p.repository?.license ?? .other,
                          summary: p.repository?.summary ?? "",
                          authors: [],
                          history: .init(since: "foo",
                                         commits: .init(name: "commits", url: "1"),
                                         releases: .init(name: "releases", url: "2")),
                          activity: .init(
                            openIssues: .init(name: "issues", url: "3"),
                            pullRequests: .init(name: "PRs", url: "4"),
                            lastPullRequestClosedMerged: "XX days ago"),
                          products: (libraries: 17, executables: 42))
        }
    }
}
