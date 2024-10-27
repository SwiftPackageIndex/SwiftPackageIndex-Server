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


enum CustomCollectionsController {

    static func query(on database: Database, name: String, page: Int, pageSize: Int) async throws -> Page<Joined3<Package, Repository, Version>> {
        try await Joined3<Package, Repository, Version>
            .query(on: database, version: .defaultBranch)
            .join(CustomCollectionPackage.self, on: \Package.$id == \CustomCollectionPackage.$package.$id)
            .join(CustomCollection.self, on: \CustomCollection.$id == \CustomCollectionPackage.$customCollection.$id)
            .filter(CustomCollection.self, \.$name == name)
            .sort(Repository.self, \.$name)
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
        guard let name = req.parameters.get("name") else {
            throw Abort(.notFound)
        }
        let query = try req.query.decode(Query.self)
        let page = try await Self.query(on: req.db, name: name, page: query.page, pageSize: query.pageSize)

        guard !page.results.isEmpty else {
            throw Abort(.notFound)
        }

        let packageInfo = page.results.compactMap(PackageInfo.init(package:))

        let model = CustomCollectionShow.Model(
            name: name,
            packages: packageInfo,
            page: query.page,
            hasMoreResults: page.hasMoreResults
        )

        return CustomCollectionShow.View(path: req.url.path, model: model).document()
    }

}
