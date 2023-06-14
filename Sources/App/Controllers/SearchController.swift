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

import Fluent
import Plot
import Vapor


enum SearchController {

    static func show(req: Request) async throws -> HTML {
        let query = try req.query.decode(API.SearchController.Query.self)

        let response = try await API.search(database: req.db,
                                            query: query,
                                            pageSize: Constants.resultsPageSize)

        let matchedKeywords = response.results.compactMap { $0.keywordResult?.keyword }

        // We're only displaying the keyword sidebar on the first search page.
        let weightedKeywords = (query.page == 1)
        ? try await WeightedKeyword.query(on: req.db, keywords: matchedKeywords)
        : []

        let model = SearchShow.Model(query: query, response: response, weightedKeywords: weightedKeywords)
        var path = req.url.string
        
        if var components = URLComponents(string: path), let queryItems = components.queryItems {
            components.queryItems = queryItems.filter { item in
                ["page", "query"].contains(item.name)
            }
            
            if let filteredPath = components.string {
                path = filteredPath
            }
        }
        
        return SearchShow.View.init(path: path, model: model).document()
    }

}
