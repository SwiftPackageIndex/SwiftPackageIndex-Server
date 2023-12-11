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

import CanonicalPackageURL
import DependencyResolution
import Fluent
import SQLKit
import Vapor


extension API {
    enum DependencyController {
        struct PackageRecord: Content, Equatable {
            var id: Package.Id
            var url: CanonicalPackageURL
            var resolvedDependencies: [CanonicalPackageURL]?
        }

        static func get(req: Request) async throws -> [PackageRecord] {
            try await query(on: req.db)
        }

        static func query(on database: Database) async throws -> [PackageRecord] {
            struct DTO: Content, Equatable {
                var id: Package.Id
                var url: String
                var resolvedDependencies: [ResolvedDependency]?

                var record: PackageRecord? {
                    guard let url = CanonicalPackageURL(url) else { return nil }
                    return PackageRecord(
                        id: id,
                        url: url,
                        resolvedDependencies: resolvedDependencies
                            .map { $0.map(\.repositoryURL).compactMap(CanonicalPackageURL.init) }
                    )
                }
            }

            guard let db = database as? SQLDatabase else {
                fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
            }
            return try await db.raw(#"""
                SELECT p.id AS "id", p.url AS "url", to_jsonb(v.resolved_dependencies) AS "resolvedDependencies"
                FROM versions v
                JOIN packages p ON v.package_id = p.id and v.latest = 'default_branch'
                """#)
            .all(decoding: DTO.self)
            .compactMap(\.record)
        }
    }
}
