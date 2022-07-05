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

import Fluent
import Plot
import Vapor


struct SearchController {

    func show(req: Request) async throws -> HTML {
                
        let query = req.query[String.self, at: "query"] ?? ""
        let page = req.query[Int.self, at: "page"] ?? 1
        
        let response = try await API.search(database: req.db,
                          query: query,
                          page: page,
                          pageSize: Constants.resultsPageSize).get()
        
        let matchedKeywords = response.results.compactMap { $0.keywordResult?.keyword }
        
        let weightedKeywords: [WeightedKeywordModel]

        if page == 1 {
            weightedKeywords = try await WeightedKeyword.query(on: req.db,keywords: matchedKeywords)
                .map { WeightedKeywordModel(keyword: $0.keyword,
                                             weight: $0.count) }
        } else {
            weightedKeywords = []
        }
        
        let model = SearchShow.Model.init(page: page, query: query, response: response, weightedKeywords: weightedKeywords)
        return SearchShow.View.init(path: req.url.path, model: model).document()
    }

}
