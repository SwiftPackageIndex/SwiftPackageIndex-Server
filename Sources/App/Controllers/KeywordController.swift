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


enum KeywordController {

    static func query(on database: Database, keyword: String, page: Int, pageSize: Int) async throws -> Page<Joined3<Package, Repository, Version>> {
        try await Joined3<Package, Repository, Version>
            .query(on: database, version: .defaultBranch)
            .field(Repository.self, \.$name)
            .field(Repository.self, \.$owner)
            .field(Repository.self, \.$lastActivityAt)
            .field(Repository.self, \.$stars)
            .field(Repository.self, \.$summary)
            .field(Version.self, \.$packageName)
            .filter(Repository.self, \.$keywords, .custom("@>"), [keyword])
            .sort(\.$score, .descending)
            .sort(Repository.self, \.$name)
            .field(\.$scoreDetails)
            .page(page, size: pageSize)
    }

    struct Query: Codable {
        var page: Int
        var pageSize: Int

        static let defaultPage = 1
        static let defaultPageSize = 20

        enum CodingKeys: CodingKey {
            case page
            case pageSize
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.page = try container.decodeIfPresent(Int.self, forKey: CodingKeys.page) ?? Self.defaultPage
            self.pageSize = try container.decodeIfPresent(Int.self, forKey: CodingKeys.pageSize) ?? Self.defaultPageSize
        }
    }

    @Sendable
    static func show(req: Request) async throws -> HTML {
        guard let keyword = req.parameters.get("keyword") else {
            throw Abort(.notFound)
        }
        let query = try req.query.decode(Query.self)

        async let page = Self.query(on: req.db, keyword: keyword, page: query.page, pageSize: query.pageSize)
        async let weightedKeywords = WeightedKeyword.query(on: req.db, keywords: [keyword])

        let (pageResult, weightedKeywordsResult) = try await (page, weightedKeywords)

        guard !pageResult.results.isEmpty else {
            throw Abort(.notFound)
        }

        let packageInfo = pageResult.results.compactMap(PackageInfo.init(package:))

        let model = KeywordShow.Model(
            keyword: keyword,
            packages: packageInfo,
            page: query.page,
            hasMoreResults: pageResult.hasMoreResults,
            totalPackageCount: weightedKeywordsResult.weight(for: keyword)
        )

        return KeywordShow.View(path: req.url.path, model: model).document()
    }

}
