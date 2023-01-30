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

extension HomeIndex {

    struct IndexSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case url, potentialAction
        }

        var context: String = "https://schema.org"
        var type: String = "WebSite"

        let url: String
        let potentialAction: SearchActionSchema

        init() {
            self.url = SiteURL.home.absoluteURL()
            self.potentialAction = .init(
                target: .init(
                    urlTemplate: SiteURL.search.absoluteURL(parameters: [
                        .init(key: "query", value: "{search_term_string}")
                    ], encodeParameters: false)
                ),
                queryInput: "required name=search_term_string"
            )
        }
    }

    struct SearchActionSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case target, queryInput = "query-input"
        }

        var context: String = "https://schema.org"
        var type: String = "SearchAction"

        let target: EntryPointSchema
        let queryInput: String

        init(target: EntryPointSchema, queryInput: String) {
            self.target = target
            self.queryInput = queryInput
        }
    }

    struct EntryPointSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case urlTemplate
        }

        var context: String = "https://schema.org"
        var type: String = "EntryPoint"

        let urlTemplate: String

        init(urlTemplate: String) {
            self.urlTemplate = urlTemplate
        }
    }
}
