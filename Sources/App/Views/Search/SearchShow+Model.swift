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

enum SearchShow {

    struct Model {
        var page: Int
        var query: String
        var term: String
        var filters: [SearchFilter.ViewModel]
        var response: Response
        var weightedKeywords: [WeightedKeyword]

        internal init(query: API.SearchController.Query,
                      response: Search.Response,
                      weightedKeywords: [WeightedKeyword]) {
            self.page = query.page ?? API.SearchController.Query.defaultPage
            self.query = (query.query ?? API.SearchController.Query.defaultQuery).sanitized()
            self.term = response.searchTerm.sanitized()
            self.filters = response.searchFilters
            self.response = Model.Response(response: response)
            self.weightedKeywords = weightedKeywords
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
            response.results.compactMap(\.keywordResult).sorted { lhs, rhs in
                let lhsWeight = weightedKeywords.weight(for: lhs.keyword)
                let rhsWeight = weightedKeywords.weight(for: rhs.keyword)
                if lhsWeight == rhsWeight {
                    return lhs.keyword < rhs.keyword
                } else {
                    return lhsWeight > rhsWeight
                }
            }
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

extension String {
    func sanitized() -> String {
        // This does not strip HTML tags as it's possible people would want to search for them.
        // Instead, it changes angle brackets and quotes and when combined with our SQL sanitisation does everything we need.
        self.replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        // Also, the `term` coming back out of the view model may contain backslash escape characters which we should not display.
            .replacingOccurrences(of: "\\", with: "")
    }
}
