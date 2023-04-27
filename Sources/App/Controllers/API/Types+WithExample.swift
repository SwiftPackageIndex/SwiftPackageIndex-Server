import Foundation

import VaporToOpenAPI


extension Date: WithExample {
    public static var example: Self { .init(rfc1123: "Sat, 25 Apr 2020 10:55:00 UTC")! }
}


extension API.SearchController.Query: WithExample {
    static var example: Self { .init(query: "LinkedList") }
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


extension Search.Response: WithExample {
    static var example: Self {
        .init(hasMoreResults: false,
              searchTerm: "LinkedList",
              searchFilters: [.example],
              results: [.example])
    }
}


extension SearchFilter.ViewModel: WithExample {
    static var example: Self {
        .init(key: "author", operator: "is", value: "mona")
    }
}
