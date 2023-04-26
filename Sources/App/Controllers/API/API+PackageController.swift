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
import Vapor


extension API {

    // periphery:ignore
    enum PackageController {

        static func index(req: Request) throws -> EventLoopFuture<[Package]> {
            return Package.query(on: req.db).all()
        }

        static func create(req: Request) throws -> EventLoopFuture<Package> {
            let pkg = try req.content.decode(Package.self)
            return pkg.save(on: req.db).map { pkg }
        }

        static func get(req: Request) throws -> EventLoopFuture<Package> {
            return Package.find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))
        }

        static func replace(req: Request) throws -> EventLoopFuture<HTTPStatus> {
            let pkg = try req.content.decode(Package.self)
            return Package.find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMap { _ in pkg.save(on: req.db) }
                .transform(to: .ok)
        }

        static func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
            return Package.find(req.parameters.get("id"), on: req.db)
                .unwrap(or: Abort(.notFound))
                .flatMap { $0.delete(on: req.db) }
                .transform(to: .ok)
        }

        static func run(req: Request) async throws -> Command.Response {
            let cmd = req.parameters.get("command")
                .flatMap(Command.init(rawValue:))
            let limit = req.query[Int.self, at: "limit"] ?? 10
            switch cmd {
                case .reconcile:
                    try await reconcile(client: req.client, database: req.db)
                    let rowCount = try await Package.query(on: req.db).count()
                    return .init(status: "ok", rows: rowCount)
                case .ingest:
                    try await ingest(client: req.application.client,
                                     database: req.application.db,
                                     logger: req.application.logger,
                                     mode: .limit(limit))
                    return .init(status: "ok", rows: limit)
                case .analyze:
                    try await Analyze.analyze(client: req.application.client,
                                              database: req.application.db,
                                              logger: req.application.logger,
                                              mode: .limit(limit))
                    return .init(status: "ok", rows: limit)
                case .none:
                    throw Abort(.notFound)
            }
        }

        static func badge(req: Request) throws -> EventLoopFuture<Badge> {
            guard
                let owner = req.parameters.get("owner"),
                let repository = req.parameters.get("repository")
            else {
                return req.eventLoop.future(error: Abort(.notFound))
            }
            guard
                let badgeType = req.query[String.self, at: "type"]
                    .flatMap(BadgeType.init(rawValue:))
            else {
                return req.eventLoop.future(error: Abort(.badRequest,
                                                         reason: "missing or invalid type parameter"))
            }

            return BadgeRoute
                .query(on: req.db, owner: owner, repository: repository)
                .map {
                    Badge(significantBuilds: $0, badgeType: badgeType)
                }
        }

    }
}


extension API.PackageController {
    enum Command: String {
        case reconcile
        case ingest
        case analyze

        struct Response: Content {
            var status: String
            var rows: Int
        }
    }
}


extension API.PackageController {
    enum BadgeRoute {
        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<SignificantBuilds> {
            Joined4<Build, Version, Package, Repository>
                .query(on: database)
                .filter(Version.self, \Version.$latest != nil)
                .filter(Repository.self, \.$owner, .custom("ilike"), owner)
                .filter(Repository.self, \.$name, .custom("ilike"), repository)
                .field(\.$platform)
                .field(\.$status)
                .field(\.$swiftVersion)
                .all()
                .mapEach {
                    ($0.build.swiftVersion, $0.build.platform, $0.build.status)
                }
                .map(SignificantBuilds.init(buildInfo:))
        }
    }
}


extension API.PackageController {
    enum TriggerBuildRoute {
        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<[Version.Id]> {
            Joined3<Package, Repository, Version>
                .query(on: database)
                .filter(Version.self, \.$latest != nil)
                .filter(Repository.self, \.$owner, .custom("ilike"), owner)
                .filter(Repository.self, \.$name, .custom("ilike"), repository)
                .field(Version.self, \.$id)
                .all()
                .flatMapEachThrowing { try $0.version.requireID() }
        }
    }
}
