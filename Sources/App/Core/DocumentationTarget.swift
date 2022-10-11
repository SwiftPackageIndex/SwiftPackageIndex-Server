// Copyright 2020-2022 Dave Verwer, Sven A. Schmidt, and other contributors.
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


enum DocumentationTarget: Equatable {
    case external(url: String)
    case `internal`(reference: String, archive: String)

    /// Fetch DocumentationTarget for a given package.
    /// - Parameters:
    ///   - database: Database connection
    ///   - owner: Repository owner
    ///   - repository: Repository name
    /// - Returns: DocumentationTarget or nil
    static func query(on database: Database, owner: String, repository: String) async throws -> Self? {
        let results = try await Joined3<Version, Package, Repository>
            .query(on: database,
                   join: \Version.$package.$id == \Package.$id, method: .inner,
                   join: \Package.$id == \Repository.$package.$id, method: .inner)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .group(.or) {
                $0
                    .filter(\Version.$docArchives != nil)
                    .filter(\Version.$spiManifest != nil)
            }
            .field(Repository.self, \.$ownerName)
            .field(Version.self, \.$commitDate)
            .field(Version.self, \.$docArchives)
            .field(Version.self, \.$latest)
            .field(Version.self, \.$packageName)
            .field(Version.self, \.$publishedAt)
            .field(Version.self, \.$reference)
            .field(Version.self, \.$spiManifest)
            .all()

        return results
            .map(\.model)
            .documentationTarget()
    }

    /// Fetch DocumentationTarget for a specific reference. This returns an `internal` DocumentationTarget by definition, because `external` targets have no notion of references.
    /// - Parameters:
    ///   - database: Database connection
    ///   - owner: Repository owner
    ///   - repository: Repository name
    ///   - reference: Version reference
    /// - Returns: DocumentationTarget or nil
    static func query(on database: Database, owner: String, repository: String, reference: Reference) async throws -> Self? {
        let archive = try await Joined3<Version, Package, Repository>
            .query(on: database,
                   join: \Version.$package.$id == \Package.$id, method: .inner,
                   join: \Package.$id == \Repository.$package.$id, method: .inner)
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .filter(\Version.$reference == reference)
            .filter(\Version.$docArchives != nil)
            .field(Version.self, \.$docArchives)
            .first()
            .flatMap { $0.model.docArchives?.first?.name }

        return archive.map {
            .internal(reference: "\(reference)", archive: $0)
        }
    }
}
