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
                 )
        ]

        // MUT
        let model = SearchShow.Model(page: 1, query: "query", response: .init(hasMoreResults: false, results: results))

        XCTAssertEqual(model.page, 1)
        XCTAssertEqual(model.query, "query")

        XCTAssertEqual(model.response.hasMoreResults, false)
        XCTAssertEqual(model.response.results.count, 2)

        let result = model.packageResults.first!
        XCTAssertEqual(result.packageId, .id1)
        XCTAssertEqual(result.packageName, "1")
        XCTAssertEqual(result.packageURL, "https://example.com/package/one")
        XCTAssertEqual(result.repositoryName, "one")
        XCTAssertEqual(result.repositoryOwner, "package")
        XCTAssertEqual(result.summary, "summary one")

        XCTAssertEqual(model.authorResults, [])
        XCTAssertEqual(model.keywordResults, [])
    }

    // TODO: add keyword and author search test
}
