@testable import App

import XCTVapor

class SearchShowModelTests: AppTestCase {

    func test_SearchShow_Model_init() throws {
        let results: [Search.Result] = [
            // Valid - All fields populated
            .mock(packageId: .id1,
                  packageName: "1",
                  packageURL: "https://example.com/package/one",
                  repositoryName: "one",
                  repositoryOwner: "package",
                  summary: "summary one"
                 ),
            // Valid - Optional fields blank
            .mock(packageId: .id2,
                  packageName: nil,
                  packageURL: "https://example.com/package/two",
                  repositoryName: "two",
                  repositoryOwner: "package",
                  summary: nil
                 ),
            // Invalid - Missing packageURL
            .mock(packageId: .id3,
                  packageName: "3",
                  packageURL: nil,
                  repositoryName: "three",
                  repositoryOwner: "package",
                  summary: "summary three"
                 ),
            // Invalid - Missing repositoryName
            .mock(packageId: .id4,
                  packageName: "4",
                  packageURL: "https://example.com/package/three",
                  repositoryName: nil,
                  repositoryOwner: "package",
                  summary: "summary four"
                 ),
            // Invalid - Missing repositoryOwner
            .mock(packageId: .id5,
                  packageName: "5",
                  packageURL: "https://example.com/package/three",
                  repositoryName: "five",
                  repositoryOwner: nil,
                  summary: "summary five"
            )
        ]

        // MUT
        let model = SearchShow.Model(page: 1, query: "query", response: .init(hasMoreResults: false, results: results))

        XCTAssertEqual(model.page, 1)
        XCTAssertEqual(model.query, "query")

        XCTAssertEqual(model.response.hasMoreResults, false)
        XCTAssertEqual(model.response.results.count, 2)

        let result = model.response.results.first!
        XCTAssertEqual(result.title, "1")
        XCTAssertEqual(result.summary, "summary one")
        XCTAssertEqual(result.footer, "package/one")
        XCTAssertEqual(result.link, "https://example.com/package/one")
    }

    func test_SearchShow_Model_Record_packageName() throws {
        // A search record with no package name shouls get a default package name
        let result: Search.Result = .mock(
            packageId: .id1,
            packageName: nil,
            packageURL: "https://example.com/package/one",
            repositoryName: "one",
            repositoryOwner: "package",
            summary: nil
        )

        let viewModel = SearchShow.Model.Result(result: result)

        // MUT
        let packageName = viewModel?.title

        XCTAssertEqual(packageName, "Unknown Package")
    }

    // TODO: add keyword search test
}
