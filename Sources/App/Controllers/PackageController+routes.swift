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
    
    func show(req: Request) async throws -> Response {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            throw Abort(.notFound)
        }

        if repository.lowercased().hasSuffix(".git") {
            throw Abort.redirect(to: SiteURL.package(.value(owner),
                                                     .value(repository.droppingGitExtension),
                                                     .none).absoluteURL(),
                                 type: .permanent)
        }

        do {
            return try await ShowRoute
                .query(on: req.db, owner: owner, repository: repository)
                .map {
                    PackageShow.View(path: req.url.path,
                                     model: $0.model, packageSchema: $0.schema)
                        .document()
                }
                .get()
                .encodeResponse(for: req)
        } catch let error as AbortError where error.status == .notFound {
            // The package is not in the index, does it match a valid GitHub repository?
            if try await Current.fetchHTTPStatusCode("https://github.com/\(owner)/\(repository)") == .notFound {
                // If GitHub 404s, we should show our standard 404.
                throw Abort(.notFound)
            } else {
                // Otherwise, show the page urging people to add the package.
                let model = MissingPackage.Model(owner: owner, repository: repository)
                // This is technically a 404 page with a different template, so it's important
                // to return a 404 so that it doesn't look like we have every possible package
                return MissingPackage.View(path: req.url.path, model: model)
                    .document()
                    .encodeResponse(for: req, status: .notFound)
            }
        }
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
                else { return req.eventLoop.future((url: nil, readme: nil)) }
                return req.client.get(URI(string: url))
                    .map { (url: url, readme: $0.body?.asString()) }
            }
            .map(PackageReadme.Model.init(url:readme:))
            .map(PackageReadme.View.init(model:))
            .map { $0.document() }
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

        return Joined3<Package, Repository, Version>
            .query(on: req.db, owner: owner, repository: repository, version: .defaultBranch)
            .field(Version.self, \.$packageName)
            .field(Repository.self, \.$owner)
            .field(Repository.self, \.$name)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMapThrowing { result in
                guard let repositoryOwner = result.repository.owner,
                      let repositoryName = result.repository.name else {
                          throw Abort(.notFound)
                      }
                return MaintainerInfoIndex.Model(
                    packageName: result.version.packageName ?? repositoryName,
                    repositoryOwner: repositoryOwner,
                    repositoryName: repositoryName
                )
            }
            .map { MaintainerInfoIndex.View(path: req.url.path, model: $0).document() }
    }
}
