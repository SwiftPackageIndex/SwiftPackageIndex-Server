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

struct PackageController {
    
    func show(req: Request) throws -> EventLoopFuture<HTML> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }
        return PackageResult
            .query(on: req.db, owner: owner, repository: repository)
            .map { result -> (PackageShow.Model, PackageShow.PackageSchema)? in
                guard
                    let model = PackageShow.Model(result: result),
                    let schema = PackageShow.PackageSchema(result: result)
                else {
                    return nil
                }
                
                return (model, schema)
            }
            .unwrap(or: Abort(.notFound))
            .map { PackageShow.View(path: req.url.path, model: $0.0, packageSchema: $0.1).document() }
    }

    func readme(req: Request) throws -> EventLoopFuture<Node<HTML.BodyContext>> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return Joined<Package, Repository>
            .query(on: req.db, owner: owner, repository: repository)
            .flatMap { result in
                guard let url = result.repository?.readmeHtmlUrl
                else { return req.eventLoop.future(nil) }
                return req.client.get(URI(string: url))
                    .map { $0.body?.asString() }
            }
            .map(PackageReadme.Model.init(readme:))
            .map { PackageReadme.View(model: $0).document() }
    }
    
    func releases(req: Request) throws -> EventLoopFuture<Node<HTML.BodyContext>> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return Joined<Package, Repository>
            .query(on: req.db, owner: owner, repository: repository)
            .map(PackageReleases.Model.init(package:))
            .map { PackageReleases.View(model: $0).document() }
    }

    func builds(req: Request) throws -> EventLoopFuture<HTML> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }
        return BuildsRoute
            .query(on: req.db, owner: owner, repository: repository)
            .map(BuildIndex.Model.init(packageInfo:buildInfo:))
            .unwrap(or: Abort(.notFound))
            .map { BuildIndex.View(path: req.url.path, model: $0).document() }
    }

    func maintainerInfo(req: Request) throws -> EventLoopFuture<HTML> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            return req.eventLoop.future(error: Abort(.notFound))
        }

        return PackageResult
            .query(on: req.db, owner: owner, repository: repository)
            .map(MaintainerInfoIndex.Model.init(result:))
            .unwrap(or: Abort(.notFound))
            .map { MaintainerInfoIndex.View(path: req.url.path, model: $0).document() }
    }
}


// TODO: move
extension PackageController {
    enum BuildsRoute {
        struct PackageInfo: Equatable {
            var packageName: String?
            var repositoryOwner: String
            var repositoryName: String

            internal init(packageName: String? = nil, repositoryOwner: String, repositoryName: String) {
                self.packageName = packageName
                self.repositoryOwner = repositoryOwner
                self.repositoryName = repositoryName
            }

            init(builds: [Build]) throws {
                guard let firstBuild = builds.first else { throw Abort(.notFound) }
                let repo = try firstBuild.joined(Repository.self)
                guard let repoOwner = repo.owner, let repoName = repo.name else {
                    throw Abort(.notFound)
                }
                let packageName = try builds
                    .compactMap { b -> (kind: Version.Kind, packageName: String?)? in
                        let v = try b.joined(Version.self)
                        guard let latest = v.latest else { return nil }
                        return (latest, v.packageName)
                    }
                    .lazy
                    .first {
                        $0.kind == .defaultBranch
                    }?.packageName
                self.packageName = packageName
                self.repositoryOwner = repoOwner
                self.repositoryName = repoName
            }

            static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<(PackageInfo)> {
#warning("use Joined here (because we're using `.joined(...)` downstream")
                return Version.query(on: database)
                    .join(parent: \.$package)
                    .join(Repository.self, on: \Repository.$package.$id == \Package.$id)
                    .filter(Version.self, \Version.$latest == .defaultBranch)
                    .filter(Repository.self, \.$owner, .custom("ilike"), owner)
                    .filter(Repository.self, \.$name, .custom("ilike"), repository)
                    .first()
                    .unwrap(or: Abort(.notFound))
                    .flatMapThrowing { version in
                        let repo = try version.joined(Repository.self)
                        guard let repoOwner = repo.owner,
                              let repoName = repo.name else {
                                  throw Abort(.notFound)
                              }
                        return .init(packageName: version.packageName,
                                     repositoryOwner: repoOwner,
                                     repositoryName: repoName)
                    }
            }
        }

        struct BuildInfo: Equatable {
            var versionKind: Version.Kind
            var reference: Reference
            var buildId: Build.Id
            var swiftVersion: SwiftVersion
            var platform: Build.Platform
            var status: Build.Status

            static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<[BuildInfo]> {
#warning("use Joined here (because we're using `.joined(...)` downstream")
                return Build.query(on: database)
                    .join(parent: \.$version)
                    .join(Package.self, on: \Version.$package.$id == \Package.$id)
                    .join(Repository.self, on: \Repository.$package.$id == \Package.$id)
                    .filter(Version.self, \Version.$latest != nil)
                    .filter(Repository.self, \.$owner, .custom("ilike"), owner)
                    .filter(Repository.self, \.$name, .custom("ilike"), repository)
                    .field(\.$id)
                    .field(\.$swiftVersion)
                    .field(\.$platform)
                    .field(\.$status)
                    .field(Version.self, \.$latest)
                    .field(Version.self, \.$packageName)
                    .field(Version.self, \.$reference)
                    .all()
                    .flatMapThrowing { builds in
                        try builds.compactMap { b -> BuildInfo? in
                            let version = try b.joined(Version.self)
                            guard let kind = version.latest,
                                  let reference = version.reference else { return nil }
                            return try BuildInfo(versionKind: kind,
                                                 reference: reference,
                                                 buildId: b.requireID(),
                                                 swiftVersion: b.swiftVersion,
                                                 platform: b.platform,
                                                 status: b.status)
                        }
                    }
            }
        }

        static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<(PackageInfo, [BuildInfo])> {
            PackageInfo.query(on: database, owner: owner, repository: repository)
                .and(BuildInfo.query(on: database, owner: owner, repository: repository))
        }
    }
}


// MARK: - PackageResult


extension PackageController {
    //    (Package - Repository) -< Version
    //                                 |
    //                                 |-< Build
    //                                 |
    //                                 '-< Product
    typealias PackageResult = Ref<Joined<Package, Repository>, Ref2<Version, Build, Product>>
}


extension PackageController.PackageResult {
    var package: Package { model.package }
    var repository: Repository? { model.repository }
    var versions: [Version] { package.versions }

    static func query(on database: Database, owner: String, repository: String) -> EventLoopFuture<Self> {
        Joined<Package, Repository>.query(on: database)
            .with(\.$versions) {
                $0.with(\.$products)
                $0.with(\.$builds)
            }
            .filter(Repository.self, \.$owner, .custom("ilike"), owner)
            .filter(Repository.self, \.$name, .custom("ilike"), repository)
            .first()
            .unwrap(or: Abort(.notFound))
            .map(Self.init(model:))
    }
}
