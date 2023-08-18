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
            var query: String = Self.defaultQuery
            var page: Int = Self.defaultPage
            var pageSize: Int = Self.defaultPageSize

            static let defaultQuery = ""
            static let defaultPage = 1
            static let defaultPageSize = 20

            enum CodingKeys: CodingKey {
                case query
                case page
                case pageSize
            }
            
            init(query: String = Self.defaultQuery, page: Int = Self.defaultPage, pageSize: Int = Self.defaultPageSize) {
                self.query = query
                self.page = page
                self.pageSize = pageSize
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.query = try container.decodeIfPresent(String.self, forKey: CodingKeys.query) ?? Self.defaultQuery
                self.page = try container.decodeIfPresent(Int.self, forKey: CodingKeys.page) ?? Self.defaultPage
                self.pageSize = try container.decodeIfPresent(Int.self, forKey: CodingKeys.pageSize) ?? Self.defaultPageSize
            }
        }

        static func get(req: Request) async throws -> Search.Response {
            let query = try req.query.decode(Query.self)
            AppMetrics.apiSearchGetTotal?.inc()
            return try await search(database: req.db,
                                    query: query)
        }
    }
}


extension API {
    static func search(database: Database,
                       query: SearchController.Query) async throws -> Search.Response {
        let terms = query.query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else {
            return .init(hasMoreResults: false,
                         searchTerm: query.query,
                         searchFilters: [],
                         results: [])
        }
        return try await Search.fetch(database,
                                      terms,
                                      page: query.page,
                                      pageSize: query.pageSize).get()
    }
}
