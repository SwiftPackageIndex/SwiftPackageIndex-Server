// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Testing


extension AllTests.SearchShowModelTests {

    @Test func SearchShow_Model_init() throws {
        let results: [Search.Result] = .mock()

        // MUT
        let model = SearchShow.Model(
            query: .init(query: "query key:value", page: 1),
            response: .init(hasMoreResults: false,
                            searchTerm: "query",
                            searchFilters: [
                                .init(key: "key", operator: "is", value: "value")
                            ],
                            results: results), weightedKeywords: [])

        #expect(model.page == 1)
        #expect(model.query == "query key:value")
        #expect(model.term == "query")

        #expect(model.filters.count == 1)
        #expect(model.filters[0].key == "key")
        #expect(model.filters[0].operator == "is")
        #expect(model.filters[0].value == "value")

        #expect(model.response.hasMoreResults == false)
        #expect(model.response.results.count == 10)
    }

    @Test func SearchShow_Model_init_sanitized() throws {
        do {
            // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1409
            let query = #"'>"></script><svg/onload=confirm(42)>"#
            // MUT
            let model = SearchShow.Model(
                query: .init(query: query, page: 1),
                response: .init(hasMoreResults: false, searchTerm: query, searchFilters: [], results: []),
                weightedKeywords: []
            )

            #expect(
                model.query == "&apos;&gt;&quot;&gt;&lt;/script&gt;&lt;svg/onload=confirm(42)&gt;"
            )
            #expect(
                model.term == "&apos;&gt;&quot;&gt;&lt;/script&gt;&lt;svg/onload=confirm(42)&gt;"
            )
        }
        do {
            // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1409
            let query = "test'two"
            // MUT
            let model = SearchShow.Model(
                query: .init(query: query, page: 1),
                response: .init(hasMoreResults: false, searchTerm: query, searchFilters: [], results: []),
                weightedKeywords: []
            )

            #expect(model.query == "test&apos;two")
            #expect(model.term == "test&apos;two")
        }
    }

    @Test func SearchShow_Model_authorResults() throws {
        let results: [Search.Result] = .mock()
        let model = SearchShow.Model(query: .init(query: "query", page: 1),
                                     response: .init(hasMoreResults: false,
                                                     searchTerm: "query",
                                                     searchFilters: [],
                                                     results: results),
                                     weightedKeywords: [])

        // MUT
        let authorResult = model.authorResults.first!

        #expect(authorResult.name == "Apple")
    }

    @Test func SearchShow_Model_keywordResults() throws {
        let results: [Search.Result] = .mock()
        let model = SearchShow.Model(query: .init(query: "query", page:1 ),
                                     response: .init(hasMoreResults: false,
                                                     searchTerm: "query",
                                                     searchFilters: [],
                                                     results: results),
                                     weightedKeywords: [])

        // MUT
        let keywordResult = model.keywordResults.first!

        #expect(keywordResult.keyword == "keyword1")
    }

    @Test func SearchShow_Model_packageResults() throws {
        let results: [Search.Result] = .mock()
        let model = SearchShow.Model(query: .init(query: "query", page: 1),
                                     response: .init(hasMoreResults: false,
                                                     searchTerm: "query",
                                                     searchFilters: [],
                                                     results: results),
                                     weightedKeywords: [])

        // MUT
        let packageResult = model.packageResults.first!

        #expect(packageResult.packageId == .id1)
        #expect(packageResult.packageName == "Package One")
        #expect(packageResult.packageURL == "https://example.com/package/one")
        #expect(packageResult.repositoryName == "one")
        #expect(packageResult.repositoryOwner == "package")
        #expect(packageResult.summary == "This is a package filled with ones.")
    }

    @Test func SearchShow_Model_matchingKeywords() throws {
        let results: [Search.Result] = .mock()
        let model = SearchShow.Model(query: .init(query: "query", page: 1),
                                     response: .init(hasMoreResults: false,
                                                     searchTerm: "query",
                                                     searchFilters: [],
                                                     results: results),
                                     weightedKeywords: [])

        // MUT
        let matchingKeywords = model.matchingKeywords(packageKeywords: ["keyword2", "keyword4", "keyword5"])

        #expect(matchingKeywords == ["keyword2", "keyword4"])
    }

}
