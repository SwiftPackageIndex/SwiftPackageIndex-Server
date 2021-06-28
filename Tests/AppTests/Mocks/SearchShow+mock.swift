@testable import App

import Foundation


extension SearchShow.Model {
    static var mock: Self {
        let results: [Search.Result] = (0..<10).map { idx in
                .mock(
                    packageId: .mockId(at: idx),
                    packageName: "Package \(idx)",
                    packageURL: "\(idx)".asGithubUrl,
                    repositoryName: "bar-\(idx)",
                    repositoryOwner: "foo",
                    summary: "Package number \(idx)")
        }
        return .init(page: 3,
                     query: "query",
                     response: .init(hasMoreResults: true, results: results))
    }
}
