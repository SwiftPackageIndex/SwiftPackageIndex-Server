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
        struct Query: Codable {
            var query: String? = Self.defaultQuery
            var page: Int? = Self.defaultPage

            static let defaultQuery = ""
            static let defaultPage = 1
        }

        static func get(req: Request) async throws -> Search.Response {
            let query = try req.query.decode(Query.self)
            Task {
                do {
                    try await Plausible.postEvent(client: req.client, kind: .api, path: .search, apiKey: .open)
                } catch {
                    req.logger.warning("Plausible.postEvent failed: \(error)")
                }
            }
            AppMetrics.apiSearchGetTotal?.inc()
            return try await search(database: req.db,
                                    query: query,
                                    pageSize: Constants.resultsPageSize)
        }
    }
}


extension API {
    static func search(database: Database,
                       query: SearchController.Query,
                       pageSize: Int) async throws -> Search.Response {
        let queryString = query.query ?? SearchController.Query.defaultQuery
        let terms = queryString.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else {
            return .init(hasMoreResults: false,
                         searchTerm: queryString,
                         searchFilters: [],
                         results: [])
        }
        return try await Search.fetch(database,
                                      terms,
                                      page: query.page ?? SearchController.Query.defaultPage,
                                      pageSize: pageSize).get()
    }
}
