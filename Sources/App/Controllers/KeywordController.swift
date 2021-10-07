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


struct KeywordController {

    // TODO: use Joined<Package, Repository> instead of 3 types?
    static func query(on database: Database, keyword: String, page: Int, pageSize: Int) -> EventLoopFuture<(packages: [JoinedPackage], hasMoreResults: Bool)> {
        JoinedPackage
            .query(on: database)
            .filter(
                DatabaseQuery.Field.path(Repository.path(for: \.$keywords), schema: Repository.schema),
                DatabaseQuery.Filter.Method.custom("@>"),
                DatabaseQuery.Value.bind([keyword])
            )
        // TODO: add a migration that defaults score to 0 and make it non-optional
        // this would then become simply
        //   .sort(\.score, .descending)
            .sort(.sql(raw: "coalesce(score, 0)"), .descending)
            .sort(Repository.self, \.$name)
//            .paginate(page: page, pageSize: pageSize)
            .all()
            .flatMapThrowing { packages in
                if packages.isEmpty {
                    throw Abort(.notFound)
                }

                return (packages: Array(packages.prefix(pageSize)),
                        hasMoreResults: packages.count > pageSize)
            }
    }

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let keyword = req.parameters.get("keyword") else {
            return req.eventLoop.future(error: Abort(.notFound))
        }
        let page = req.query[Int.self, at: "page"] ?? 1
        let pageSize = Constants.resultsPageSize

        return Self.query(on: req.db, keyword: keyword, page: page, pageSize: pageSize)
            .map { packages, hasMoreResults in
                let packageInfo = packages.prefix(pageSize)
                    .compactMap(PackageInfo.init(package:))
                return KeywordShow.Model(
                    keyword: keyword,
                    packages: packageInfo,
                    page: page,
                    hasMoreResults: hasMoreResults
                )
            }
            .map {
                KeywordShow.View(path: req.url.path, model: $0).document()
            }
    }

}
