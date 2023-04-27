import Foundation

import VaporToOpenAPI


extension Date: WithExample {
    public static var example: Self { .init(rfc1123: "Sat, 25 Apr 2020 10:55:00 UTC")! }
}


extension Search.Result: WithExample {
    static var example: Self {
        .package(
            .init(packageId: .example,
                  packageName: "LinkedList",
                  packageURL: "https://github.com/mona/LinkedList.git",
                  repositoryName: "LinkedList",
                  repositoryOwner: "mona",
                  stars: 123,
                  lastActivityAt: .example,
                  summary: "An example package",
                  keywords: [],
                  hasDocs: true)!
        )
    }
}


extension SearchFilter.ViewModel: WithExample {
    static var example: Self {
        .init(key: "author", operator: "is", value: "mona")
    }
}
