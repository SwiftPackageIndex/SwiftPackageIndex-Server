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

enum SearchShow {

    struct Model {
        var page: Int
        var query: String
        var response: Response
        
        internal init(page: Int, query: String, response: Search.Response) {
            self.page = page
            self.query = query
            self.response = Model.Response(response: response)
        }

        struct Response {
            var hasMoreResults: Bool
            var results: [Model.Result]

            init(response: Search.Response) {
                self.hasMoreResults = response.hasMoreResults
                self.results = response.results.compactMap(Model.Result.init)
            }
        }

        struct Result {
            var title: String
            var summary: String?
            var footer: String
            var link: String

            init?(result: Search.Result) {
                switch result {
                    case let .author(res):
                        title = "✍️ \(res.name)"
                        link = SiteURL.author(.value(res.name)).relativeURL()
                        footer = "Author results"
                    case let .keyword(res):
                        title = "🏷 \(res.keyword)"
                        link = SiteURL.keywords(.value(res.keyword)).relativeURL()
                        footer = "Keyword results"
                    case let .package(pkg):
                        guard let packageURL = pkg.packageURL,
                              let repositoryName = pkg.repositoryName,
                              let repositoryOwner = pkg.repositoryOwner
                        else { return nil }
                        title = pkg.packageName ?? "Unknown Package"
                        summary = pkg.summary
                        footer = "\(repositoryOwner)/\(repositoryName)"
                        link = packageURL
                }
            }
        }
    }

}
