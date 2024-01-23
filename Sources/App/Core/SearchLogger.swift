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

import Foundation

struct SearchQuery: Hashable, Codable {
    let searchID: UUID
    let query: String
}

struct SearchResultFragment: Hashable, Codable {
    let searchID: UUID
    let result: Search.Result?

    enum CodingKeys: String, CodingKey {
        case searchID = "id"
        case result = "r"
    }
}

enum SearchLogger {
    static func log(query: String, results: [Search.Result]) {
        guard Current.environment() != .production else { return }
        let uniqueSearchID = UUID()
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = .sortedKeys

        let baseQuery = SearchQuery(searchID: uniqueSearchID, query: query)
        do {
            let stringdata = String(decoding: try jsonEncoder.encode(baseQuery), as: UTF8.self)
            AppEnvironment.logger.info("search: \(stringdata)")
        } catch {
            AppEnvironment.logger.warning("unable to encode search query: \(error)")
        }

        for (idx, result) in results.enumerated() {
            let fragment = SearchResultFragment(searchID: uniqueSearchID, result: result)
            do {
                let stringdata = String(decoding: try jsonEncoder.encode(fragment), as: UTF8.self)
                AppEnvironment.logger.info("searchresult[\(idx)]: \(stringdata)")
            } catch {
                AppEnvironment.logger.warning("unable to encode search fragment: \(error)")
            }
        }
    }
}
