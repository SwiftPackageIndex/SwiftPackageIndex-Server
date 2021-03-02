@testable import App

import XCTVapor

class SearchShowModelTests: AppTestCase {

    func test_SearchShow_Model_init() throws {
        let results = [
            // Valid - All fields populated
            Search.Record(packageId: .mockId(at: 1),
                          packageName: "1",
                          packageURL: "https://example.com/package/one",
                          repositoryName: "one",
                          repositoryOwner: "package",
                          summary: "summary one"
            ),
            // Valid - Optional fields blank
            Search.Record(packageId: .mockId(at: 2),
                          packageName: nil,
                          packageURL: "https://example.com/package/two",
                          repositoryName: "two",
                          repositoryOwner: "package",
                          summary: nil
            ),
            // Invalid - Missing packageURL
            Search.Record(packageId: .mockId(at: 3),
                          packageName: "3",
                          packageURL: nil,
                          repositoryName: "three",
                          repositoryOwner: "package",
                          summary: "summary three"
            ),
            // Invalid - Missing repositoryName
            Search.Record(packageId: .mockId(at: 4),
                          packageName: "4",
                          packageURL: "https://example.com/package/three",
                          repositoryName: nil,
                          repositoryOwner: "package",
                          summary: "summary four"
            ),
            // Invalid - Missing repositoryOwner
            Search.Record(packageId: .mockId(at: 5),
                          packageName: "5",
                          packageURL: "https://example.com/package/three",
                          repositoryName: "five",
                          repositoryOwner: nil,
                          summary: "summary five"
            )
        ]

        // MUT
        let model = SearchShow.Model(page: 1, query: "query", result: .init(hasMoreResults: false, results: results))

        XCTAssertEqual(model.page, 1)
        XCTAssertEqual(model.query, "query")

        XCTAssertEqual(model.result.hasMoreResults, false)
        XCTAssertEqual(model.result.results.count, 2)

        let result = model.result.results.first!
        XCTAssertEqual(result.packageId, .mockId(at: 1))
        XCTAssertEqual(result.packageName, "1")
        XCTAssertEqual(result.packageURL, "https://example.com/package/one")
        XCTAssertEqual(result.repositoryName, "one")
        XCTAssertEqual(result.repositoryOwner, "package")
        XCTAssertEqual(result.summary, "summary one")
    }

    func test_SearchShow_Model_Record_packageName() throws {
        // A search record with no package name shouls get a default package name
        let model = Search.Record(packageId: .mockId(at: 1),
                                  packageName: nil,
                                  packageURL: "https://example.com/package/one",
                                  repositoryName: "one",
                                  repositoryOwner: "package",
                                  summary: nil)

        let viewModel = SearchShow.Model.Record(record: model)

        // MUT
        let packageName = viewModel?.packageName

        XCTAssertEqual(packageName, "Unknown Package")
    }
}
