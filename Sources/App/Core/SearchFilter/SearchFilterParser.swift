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

import Foundation

struct SearchFilterParser {
    
    /// A list of all currently supported search filters.
    static var allSearchFilters: [SearchFilter.Type] = [
        StarsSearchFilter.self,
        LicenseSearchFilter.self,
        LastCommitSearchFilter.self,
        LastActivitySearchFilter.self,
        AuthorSearchFilter.self,
        KeywordSearchFilter.self,
        PlatformSearchFilter.self,
    ]
    
    /// Separates search terms from filter syntax.
    ///
    /// A "filter syntax" is a part of the user input which is a set of instructions to the search controller to filter the results by. "Search terms" is anything which is not
    /// a valid filter syntax.
    ///
    /// In this example: `["test", "stars:>500"]` - `"test"` is a search term, and `"stars:>500"` is filter syntax (instructing the search controller to
    /// only return results with more than 500 stars.)
    func split(terms: [String]) -> (terms: [String], filters: [SearchFilter]) {
        return terms.reduce(into: (terms: [], filters: [])) { builder, term in
            if let filter = parse(term: term) {
                builder.filters.append(filter)
            } else {
                builder.terms.append(term)
            }
        }
    }
    
    /// Attempts to identify the appropriate `SearchFilter` for the provided term. If it does not match our filter syntax, then this will return `nil` and it should
    /// be treated as a search term.
    func parse(term: String, allFilters: [SearchFilter.Type] = SearchFilterParser.allSearchFilters) -> SearchFilter? {
        let components = term
            .components(separatedBy: ":")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard components.count == 2 else {
            return nil
        }
        
        // Operator
        let comparison: (length: Int, value: SearchFilterComparison) = {
            let value = components[1]
            switch value {
                case _ where value.hasPrefix(">="):
                    return (2, .greaterThanOrEqual)
                case _ where value.hasPrefix(">"):
                    return (1, .greaterThan)
                case _ where value.hasPrefix("<="):
                    return (2, .lessThanOrEqual)
                case _ where value.hasPrefix("<"):
                    return (1, .lessThan)
                case _ where value.hasPrefix("!"):
                    return (1, .negativeMatch)
                default:
                    return (0, .match)
            }
        }()
        
        // Value
        let stringValue = String(components[1].dropFirst(comparison.length))
        guard !stringValue.isEmpty else { return nil }
        
        // Filter
        guard let matchingFilter = allFilters.first(where: { $0.key == components[0] }) else {
            return nil
        }
        
        AppMetrics.apiSearchGetWithFilterTotal?.inc(1, .init(key: matchingFilter.key))
        
        return try? matchingFilter.init(value: stringValue, comparison: comparison.value)
    }
    
}
