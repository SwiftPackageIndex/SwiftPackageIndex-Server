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

        return PackageResult.query(on: req.db, owner: owner, repository: repository)
            .flatMap { result in
                fetchReadme(client: req.client, package: result.model)
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
        return PackageResult
            .query(on: req.db, owner: owner, repository: repository)
            .map(BuildIndex.Model.init(result:))
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


private func fetchReadme(client: Client, package: Joined<Package, Repository>) -> EventLoopFuture<String?> {
    guard let url = package.repository?.readmeHtmlUrl.map(URI.init(string:))
    else { return client.eventLoop.future(nil) }
    return client.get(url).map { $0.body?.asString() }
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
        M.query(on: database)
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
