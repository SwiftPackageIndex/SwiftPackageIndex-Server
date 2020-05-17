import Foundation


// FIXME: fill with query
func mockModel(_ package: Package) -> PackageShowView.Model {
    .init(title: "Alamofire",
          url: URL(string: "https://github.com/Alamofire/Alamofire.git")!,
          license: .mit,
          summary: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque quis porttitor erat. Vivamus porttitor mi odio, quis imperdiet velit blandit id. Vivamus vehicula urna eget ipsum laoreet, sed porttitor sapien malesuada. Mauris faucibus tellus at augue vehicula, vitae aliquet felis ullamcorper. Praesent vitae leo rhoncus, egestas elit id, porttitor lacus. Cras ac bibendum mauris. Praesent luctus quis nulla sit amet tempus. Ut pharetra non augue sed pellentesque.",
          authors: [
            .init(name: "Christian Noon", url: URL(string: "https://github.com/cnoon")!),
            .init(name: "Mattt", url: URL(string: "https://github.com/mattt")!),
            .init(name: "Jon Shier", url: URL(string: "https://github.com/jshier")!),
            .init(name: "Kevin Harwood", url: URL(string: "https://github.com/kcharwood")!),
            .init(name: "186 other contributors", url: URL(string: "https://github.com/Alamofire/Alamofire/graphs/contributors")!),
        ],
          history: .init(
            since: "over 5 years",
            commits: .init(name: "1,433 commits",
                           url: URL(string: "https://github.com/Alamofire/Alamofire/commits/master")!),
            releases: .init(name: "79 releases",
                            url: URL(string: "https://github.com/Alamofire/Alamofire/releases")!)
        ),
          activity: .init(
            openIssues: .init(name: "27 open issues",
                              url: URL(string: "https://github.com/Alamofire/Alamofire/issues")!),
            pullRequests: .init(name: "5 open pull requests",
                                url: URL(string: "https://github.com/Alamofire/Alamofire/pulls")!),
            lastPullRequestClosedMerged: "6 days ago"),
          products: (libraries: 3, executables: 1)
    )
}
