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


enum KeywordController {

    static func query(on database: Database, keyword: String, page: Int, pageSize: Int) -> EventLoopFuture<Page<Joined3<Package, Repository, Version>>> {
        Joined3<Package, Repository, Version>
            .query(on: database, version: .defaultBranch)
            .filter(Repository.self, \.$keywords, .custom("@>"), [keyword])
            .sort(\.$score, .descending)
            .sort(Repository.self, \.$name)
            .page(page, size: pageSize)
    }

    static func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let keyword = req.parameters.get("keyword") else {
            return req.eventLoop.future(error: Abort(.notFound))
        }
        let pageIndex = req.query[Int.self, at: "page"] ?? 1
        let pageSize = Constants.resultsPageSize

        return Self.query(on: req.db, keyword: keyword, page: pageIndex, pageSize: pageSize)
            .flatMapThrowing { page in
                guard !page.results.isEmpty else {
                    throw Abort(.notFound)
                }
                let packageInfo = page.results
                    .compactMap(PackageInfo.init(package:))
                return KeywordShow.Model(
                    keyword: keyword,
                    packages: packageInfo,
                    page: pageIndex,
                    hasMoreResults: page.hasMoreResults
                )
            }
            .map {
                KeywordShow.View(path: req.url.path, model: $0).document()
            }
    }

}
