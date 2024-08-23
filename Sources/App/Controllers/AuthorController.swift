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


enum AuthorController {

    static func query(on database: Database, owner: String) async throws -> [Joined3<Package, Repository, Version>] {
        let packages = try await Joined3<Package, Repository, Version>
            .query(on: database, version: .defaultBranch)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .sort(Version.self, \.$packageName)
            .all()

        if packages.isEmpty { throw Abort(.notFound) }

        return packages
    }

    @Sendable
    static func show(req: Request) async throws -> HTML {
        guard let owner = req.parameters.get("owner") else {
            throw Abort(.notFound)
        }

        let packages = try await Self.query(on: req.db, owner: owner)

        let model = AuthorShow.Model(
            owner: packages.first?.repository.owner ?? owner,
            ownerName: packages.first?.repository.ownerDisplayName ?? owner,
            packages: packages.compactMap(PackageInfo.init(package:))
        )

        return AuthorShow.View(path: req.url.path, model: model).document()
    }

}
