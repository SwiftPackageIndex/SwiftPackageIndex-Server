// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import XCTVapor

class SearchShowModelTests: XCTestCase {

    func test_SearchShow_Model_init() throws {
        let results: [Search.Result] = .mock()

        // MUT
        let model = SearchShow.Model(
            page: 1, query: "query key:value",
            response: .init(hasMoreResults: false,
                            searchTerm: "query",
                            searchFilters: [
                                .init(key: "key", operator: "is", value: "value")
                            ],
                            results: results))

        XCTAssertEqual(model.page, 1)
        XCTAssertEqual(model.query, "query key:value")
        XCTAssertEqual(model.term, "query")

        XCTAssertEqual(model.filters.count, 1)
        XCTAssertEqual(model.filters[0].key, "key")
        XCTAssertEqual(model.filters[0].operator, "is")
        XCTAssertEqual(model.filters[0].value, "value")

        XCTAssertEqual(model.response.hasMoreResults, false)
        XCTAssertEqual(model.response.results.count, 10)
    }

    func test_SearchShow_Model_authorResults() throws {
        let results: [Search.Result] = .mock()
        let model = SearchShow.Model(page: 1, query: "query", response: .init(hasMoreResults: false,
                                                                              searchTerm: "query",
                                                                              searchFilters: [],
                                                                              results: results))

        // MUT
        let authorResult = model.authorResults.first!

        XCTAssertEqual(authorResult.name, "Apple")
    }

    func test_SearchShow_Model_keywordResults() throws {
        let results: [Search.Result] = .mock()
        let model = SearchShow.Model(page: 1, query: "query", response: .init(hasMoreResults: false,
                                                                              searchTerm: "query",
                                                                              searchFilters: [],
                                                                              results: results))

        // MUT
        let keywordResult = model.keywordResults.first!

        XCTAssertEqual(keywordResult.keyword, "keyword1")
    }

    func test_SearchShow_Model_packageResults() throws {
        let results: [Search.Result] = .mock()
        let model = SearchShow.Model(page: 1, query: "query", response: .init(hasMoreResults: false,
                                                                              searchTerm: "query",
                                                                              searchFilters: [],
                                                                              results: results))

        // MUT
        let packageResult = model.packageResults.first!

        XCTAssertEqual(packageResult.packageId, .id1)
        XCTAssertEqual(packageResult.packageName, "Package One")
        XCTAssertEqual(packageResult.packageURL, "https://example.com/package/one")
        XCTAssertEqual(packageResult.repositoryName, "one")
        XCTAssertEqual(packageResult.repositoryOwner, "package")
        XCTAssertEqual(packageResult.summary, "This is a package filled with ones.")
    }

    func test_SearchShow_Model_matchingKeywords() throws {
        let results: [Search.Result] = .mock()
        let model = SearchShow.Model(page: 1, query: "query", response: .init(hasMoreResults: false,
                                                                              searchTerm: "query",
                                                                              searchFilters: [],
                                                                              results: results))

        // MUT
        let matchingKeywords = model.matchingKeywords(packageKeywords: ["keyword2", "keyword4", "keyword5"])

        XCTAssertEqual(matchingKeywords, ["keyword2", "keyword4"])
    }
}
