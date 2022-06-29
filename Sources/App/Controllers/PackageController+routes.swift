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

        switch try await ShowModel(db: req.db, owner: owner, repository: repository) {
            case let .packageAvailable(model, schema):
                AppMetrics.packageShowAvailableTotal?.inc()
                return try await PackageShow.View(path: req.url.path,
                                                  model: model, packageSchema: schema)
                .document()
                .encodeResponse(for: req)
            case let .packageMissing(model):
                // This is technically a 404 page with a different template, so it's important
                // to return a 404 so that it doesn't look like we have every possible package
                AppMetrics.packageShowMissingTotal?.inc()
                return MissingPackage.View(path: req.url.path, model: model)
                    .document()
                    .encodeResponse(for: req, status: .notFound)
            case .packageDoesNotExist:
                // If GitHub 404s, we throw notFound, which will render our standard 404 page.
                AppMetrics.packageShowNonexistentTotal?.inc()
                throw Abort(.notFound)
        }
    }

    enum Fragment: String {
        case css
        case data
        case documentation
        case images
        case index
        case js
        case root
        case themeSettings

        var contentType: String {
            switch self {
                case .css:
                    return "text/css"
                case  .data, .images, .index, .root, .themeSettings:
                    return "application/octet-stream"
                case .documentation:
                    return "text/html; charset=utf-8"
                case .js:
                    return "application/javascript"
            }
        }
    }

    func documentation(req: Request, fragment: Fragment) async throws -> Response {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository"),
            let reference = req.parameters.get("reference")
        else {
            throw Abort(.notFound)
        }

        let path = req.parameters.getCatchall().joined(separator: "/")

        let url = try Self.awsDocumentationURL(owner: owner, repository: repository, reference: reference, fragment: fragment, path: path)
        let awsResponse = try await Current.fetchDocumentation(req.client, url)
        guard (200..<399).contains(awsResponse.status.code) else {
            // Convert anything that isn't a 2xx or 3xx into a 404
            return try await DocumentationErrorPage.View(path: req.url.path,
                                                         error: Abort(awsResponse.status))
            .document()
            .encodeResponse(status: .notFound,
                            headers: req.headers.replacingOrAdding(name: .cacheControl,
                                                                   value: "no-cache"),
                            for: req)
        }

        switch fragment {
            case .documentation:
                // Try and parse the page and add our header, but fall back to the unprocessed page if it fails.
                guard let queryResult = try await Joined3<Package, Repository, Version>
                    .query(on: req.db, owner: owner, repository: repository, version: .defaultBranch)
                    .field(Version.self, \.$packageName)
                    .field(Version.self, \.$spiManifest)
                    .field(Repository.self, \.$ownerName)
                    .first(),
                      let body = awsResponse.body,
                      let processor = DocumentationPageProcessor(repositoryOwner: owner,
                                                                 repositoryOwnerName: queryResult.repository.ownerName ?? owner,
                                                                 repositoryName: repository,
                                                                 packageName: queryResult.version.packageName ?? repository,
                                                                 reference: reference,
                                                                 docArchives: queryResult.version.spiManifest?.allDocumentationTargets() ?? [],
                                                                 isLatestStableVersion: false,
                                                                 allAvailableDocumentationVersions: [],
                                                                 rawHtml: body.asString())
                else {
                    return try await awsResponse.encodeResponse(
                        status: .ok,
                        headers: req.headers.replacingOrAdding(name: .contentType,
                                                               value: fragment.contentType),
                        for: req
                    )
                }

                return try await processor.processedPage.encodeResponse(
                    status: .ok,
                    headers: req.headers.replacingOrAdding(name: .contentType,
                                                           value: fragment.contentType),
                    for: req
                )

            case .css, .data, .images, .index, .js, .root, .themeSettings:
                return try await awsResponse.encodeResponse(
                    status: .ok,
                    headers: req.headers
                        .replacingOrAdding(name: .contentType,
                                           value: fragment.contentType)
                        .replacingOrAdding(name: .cacheControl,
                                           value: "no-transform"),
                    for: req
                )
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

    func builds(req: Request) async throws -> HTML {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            throw Abort(.notFound)
        }
        
        let (packageInfo, buildInfo) = try await BuildsRoute.query(on: req.db,
                                                                   owner: owner,
                                                                   repository: repository)

        guard let model = BuildIndex.Model(packageInfo: packageInfo, buildInfo: buildInfo)
        else { throw Abort(.notFound) }

        return BuildIndex.View(path: req.url.path, model: model).document()
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
            .field(Repository.self, \.$ownerName)
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
                    repositoryOwnerName: result.repository.ownerName ?? repositoryOwner,
                    repositoryName: repositoryName
                )
            }
            .map { MaintainerInfoIndex.View(path: req.url.path, model: $0).document() }
    }
}


extension PackageController {

    enum ShowModel {
        case packageAvailable(PackageShow.Model, PackageShow.PackageSchema)
        case packageMissing(MissingPackage.Model)
        case packageDoesNotExist

        init(db: Database, owner: String, repository: String) async throws {
            do {
                let (model, schema) = try await ShowRoute
                    .query(on: db, owner: owner, repository: repository)
                self = .packageAvailable(model, schema)
            } catch let error as AbortError where error.status == .notFound {
                // When the package is not in the index, we check if it's available on GitHub.
                // We use try? to avoid raising internel server errors from exceptions raised
                // from this call.
                let status = try? await Current.fetchHTTPStatusCode("https://github.com/\(owner)/\(repository)")
                switch status {
                    case .some(.notFound):
                        // GitHub does not have the package
                        self = .packageDoesNotExist
                    case .some(.ok), .some(.permanentRedirect), .some(.temporaryRedirect):
                        // The package is available on GitHub, we are therefore missing it
                        self = .packageMissing(.init(owner: owner, repository: repository))
                    case .some:
                        // We're getting an unexpected response from GitHub (could be an
                        // an auth error, for example) - treat this the same as the .none
                        // case: avoid showing the missing package page when we're not sure
                        // it can be added.
                        self = .packageDoesNotExist
                    case .none:
                        // There was an error contacting GitHub - treat this unknown state
                        // as if the package didn't exist on GitHub. We want to avoid showing
                        // our missing package page unless we're certain the package can be
                        // added.
                        self = .packageDoesNotExist
                }
            }
        }
    }

}


extension PackageController {
    static func awsDocumentationURL(owner: String, repository: String, reference: String, fragment: Fragment, path: String) throws -> URI {
        guard let bucket = Current.awsDocsBucket() else {
            throw AppError.envVariableNotSet("AWS_DOCS_BUCKET")
        }

        let baseURLHost = "\(bucket).s3-website.us-east-2.amazonaws.com"
        let baseURLPath = "\(owner.lowercased())/\(repository.lowercased())/\(reference.lowercased())"
        let baseURL = "http://\(baseURLHost)/\(baseURLPath)"

        switch fragment {
            case .css, .data, .documentation, .images, .index, .js:
                return URI(string: "\(baseURL)/\(fragment)/\(path)")
            case .root:
                return URI(string: "\(baseURL)/\(path)")
            case .themeSettings:
                return URI(string: "\(baseURL)/theme-settings.json")
        }
    }
}


private extension HTTPHeaders {
    func replacingOrAdding(name: Name, value: String) -> Self {
        var headers = self
        headers.replaceOrAdd(name: name, value: value)
        return headers
    }
}
