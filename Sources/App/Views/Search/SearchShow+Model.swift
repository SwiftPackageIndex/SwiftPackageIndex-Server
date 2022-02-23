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

enum SearchShow {

    struct Model {
        var page: Int
        var query: String
        var term: String
        var filters: [SearchFilter.ViewModel]
        var response: Response
        
        internal init(page: Int, query: String, response: Search.Response) {
            self.page = page
            self.query = query
            self.term = response.searchTerm
            self.filters = response.searchFilters
            self.response = Model.Response(response: response)
        }

        struct Response {
            var hasMoreResults: Bool
            var results: [Search.Result]

            init(response: Search.Response) {
                self.hasMoreResults = response.hasMoreResults
                self.results = response.results
            }
        }

        var authorResults: [Search.AuthorResult] {
            response.results.compactMap(\.authorResult)
        }

        var keywordResults: [Search.KeywordResult] {
            response.results.compactMap(\.keywordResult)
        }

        var packageResults: [Search.PackageResult] {
            response.results.compactMap(\.packageResult)
        }

        func matchingKeywords(packageKeywords: [String]?) -> [String] {
            let keywordResults = keywordResults.map { $0.keyword }
            return Array(Set(packageKeywords ?? []).intersection(Set(keywordResults))).sorted()
        }
    }

}
