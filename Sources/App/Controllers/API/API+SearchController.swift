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
import Vapor


extension API {
    struct SearchController {
        static func get(req: Request) throws -> EventLoopFuture<Search.Response> {
            let query = req.query[String.self, at: "query"] ?? ""
            let page = req.query[Int.self, at: "page"] ?? 1
            AppMetrics.apiSearchGetTotal?.inc()
            return search(database: req.db,
                          query: query,
                          page: page,
                          pageSize: Constants.resultsPageSize)
        }
    }
}


extension API {
    static func search(database: Database,
                       query: String,
                       page: Int,
                       pageSize: Int) -> EventLoopFuture<Search.Response> {
        let terms = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else {
            return database.eventLoop.future(.init(hasMoreResults: false,
                                                   searchTerm: query,
                                                   searchFilters: [],
                                                   results: []))
        }
        return Search.fetch(database, terms, page: page, pageSize: pageSize)
    }
}
