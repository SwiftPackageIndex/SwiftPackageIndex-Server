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
        return JPRVB.query(on: req.db, owner: owner, repository: repository)
            .map { package -> (PackageShow.Model, PackageShow.PackageSchema)? in
                guard
                    let model = PackageShow.Model(package: package),
                    let schema = PackageShow.PackageSchema(package: package)
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

        return JPRVB.query(on: req.db, owner: owner, repository: repository)
            .flatMap { package in
                fetchReadme(client: req.client, package: package.jpr)
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

        return JPRVB.query(on: req.db, owner: owner, repository: repository)
            .map(\.jpr)
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
        return JPRVB.query(on: req.db, owner: owner, repository: repository)
            .map(BuildIndex.Model.init(package:))
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

        return JPRVB.query(on: req.db, owner: owner, repository: repository)
            .map(MaintainerInfoIndex.Model.init(package:))
            .unwrap(or: Abort(.notFound))
            .map { MaintainerInfoIndex.View(path: req.url.path, model: $0).document() }
    }
}


private func fetchReadme(client: Client, package: JPR) -> EventLoopFuture<String?> {
    guard let url = package.repository?.readmeHtmlUrl.map(URI.init(string:))
    else { return client.eventLoop.future(nil) }
    return client.get(url).map { $0.body?.asString() }
}
