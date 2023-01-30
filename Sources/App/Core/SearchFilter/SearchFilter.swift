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


enum SearchFilter {

    /// Separates search terms from filter syntax.
    ///
    /// A "filter syntax" is a part of the user input which is a set of instructions to the search controller to filter the results by. "Search terms" is anything which is not
    /// a valid filter syntax.
    ///
    /// In this example: `["test", "stars:>500"]` - `"test"` is a search term, and `"stars:>500"` is filter syntax (instructing the search controller to
    /// only return results with more than 500 stars.)
    static func split(terms: [String]) -> (terms: [String], filters: [SearchFilterProtocol]) {
        return terms.reduce(into: (terms: [], filters: [])) { builder, term in
            if let filter = parse(filterTerm: term) {
                builder.filters.append(filter)
            } else {
                builder.terms.append(term)
            }
        }
    }

    /// Attempts to identify the appropriate `SearchFilter` for the provided term. If it does not match our filter syntax, then this will return `nil` and it should
    /// be treated as a search term.
    static func parse(filterTerm: String) -> SearchFilterProtocol? {
        let components = filterTerm
            .components(separatedBy: ":")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard components.count == 2,
              let key = Key(rawValue: components[0]),
              let expression = Expression(predicate: components[1])
        else { return nil }

        AppMetrics.apiSearchGetWithFilterTotal?.inc(1, .searchFilterLabels(key))

        return try? key.searchFilter.init(expression: expression)
    }

}


enum SearchFilterError: Error {
    case invalidValueType
    case unsupportedComparisonMethod
}
