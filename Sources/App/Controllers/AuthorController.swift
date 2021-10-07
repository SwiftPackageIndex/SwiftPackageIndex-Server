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


struct AuthorController {

    static func query(on database: Database, owner: String) -> EventLoopFuture<[Joined<Package, Repository, Version>]> {
        Joined<Package, Repository, Version>
            .query(on: database,
                   join: \Repository.$package.$id == \Package.$id,
                   method: .inner,
                   join: \Version.$package.$id == \Package.$id,
                   method: .left)
            .filter(
                DatabaseQuery.Field.path(Repository.path(for: \.$owner), schema: Repository.schema),
                DatabaseQuery.Filter.Method.custom("ilike"),
                DatabaseQuery.Value.bind(owner)
            )
            .filter(Version.self, \.$latest == .defaultBranch)
            .sort(.sql(raw: "coalesce(score, 0)"), .descending)
            .all()
            .flatMapThrowing {
                if $0.isEmpty {
                    throw Abort(.notFound)
                }
                return $0
            }
    }

    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard let owner = req.parameters.get("owner") else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return Self.query(on: req.db, owner: owner)
            .map {
                AuthorShow.Model(
                    owner: $0.first?.repository?.owner ?? owner,
                    ownerName: $0.first?.repository?.ownerDisplayName ?? owner,
                    packages: $0.compactMap(PackageInfo.init(package:))
                )
            }
            .map {
                AuthorShow.View(path: req.url.path, model: $0).document()
            }
    }

}
