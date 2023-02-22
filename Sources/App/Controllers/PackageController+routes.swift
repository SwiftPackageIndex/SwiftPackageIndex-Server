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
import SemanticVersion


enum PackageController {

    static func show(req: Request) async throws -> Response {
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
                    .encodeResponse(status: .notFound)
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
        case faviconIco = "favicon.ico"
        case faviconSvg = "favicon.svg"
        case images
        case img
        case index
        case js
        case themeSettings = "theme-settings.json"
        case tutorials

        var contentType: String {
            switch self {
                case .css:
                    return "text/css"
                case  .data, .faviconIco, .faviconSvg, .images, .img, .index, .themeSettings:
                    return "application/octet-stream"
                case .documentation, .tutorials:
                    return "text/html; charset=utf-8"
                case .js:
                    return "application/javascript"
            }
        }
    }

    static func defaultDocumentation(req: Request, fragment: Fragment) async throws -> Response {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            throw Abort(.notFound)
        }
        let anchor = req.url.fragment.map { "#\($0)"} ?? ""
        let path = req.parameters.getCatchall().joined(separator: "/").lowercased() + anchor

        guard let target = try await DocumentationTarget.query(on: req.db,
                                                               owner: owner,
                                                               repository: repository)
        else {
            throw Abort(.notFound)
        }

        throw Abort.redirect(to: SiteURL.relativeURL(owner: owner,
                                                     repository: repository,
                                                     documentation: target,
                                                     fragment: fragment,
                                                     path: path))
    }

    static func documentation(req: Request) async throws -> Response {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository"),
            let reference = req.parameters.get("reference")
        else {
            throw Abort(.notFound)
        }

        let referenceToMatch: Reference = SemanticVersion(reference)
            .map { .tag($0, reference) } ?? .branch(reference)

        guard let target = try await DocumentationTarget.query(on: req.db,
                                                               owner: owner,
                                                               repository: repository,
                                                               reference: referenceToMatch)
        else { throw Abort(.notFound) }

        throw Abort.redirect(to: SiteURL.relativeURL(owner: owner,
                                                     repository: repository,
                                                     documentation: target,
                                                     fragment: .documentation))
    }

    static func documentation(req: Request, fragment: Fragment) async throws -> Response {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository"),
            let reference = req.parameters.get("reference")
        else {
            throw Abort(.notFound)
        }

        let archive = req.parameters.get("archive")
        let catchAll = [archive].compactMap { $0 } + req.parameters.getCatchall()
        let path: String
        switch fragment {
            case .data, .documentation, .tutorials:
                // DocC lowercases "target" names in URLs. Since these routes can also
                // appear in user generated content which might use uppercase spelling, we need
                // to lowercase the input in certain cases.
                // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2168
                // and https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2172
                // for details.
                path = catchAll.joined(separator: "/").lowercased()
            case .css, .faviconIco, .faviconSvg, .images, .img, .index, .js, .themeSettings:
                path = catchAll.joined(separator: "/")
        }

        let awsResponse = try await awsResponse(client: req.client, owner: owner, repository: repository, reference: reference, fragment: fragment, path: path)

        switch fragment {
            case .documentation, .tutorials:
                let documentationVersions = try await DocumentationVersion
                    .query(on: req.db, owner: owner, repository: repository)

                return try await documentationResponse(
                    req: req,
                    archive: archive,
                    awsResponse: awsResponse,
                    documentationVersions: documentationVersions,
                    fragment: fragment,
                    owner: owner,
                    reference: reference,
                    repository: repository
                )

            case .css, .data, .faviconIco, .faviconSvg, .images, .img, .index, .js, .themeSettings:
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

    static func documentationResponse(req: Request,
                                      archive: String?,
                                      awsResponse: ClientResponse,
                                      documentationVersions: [DocumentationVersion],
                                      fragment: Fragment,
                                      owner: String,
                                      reference: String,
                                      repository: String) async throws -> Response {

        guard let documentation = documentationVersions[reference: reference]
        else {
            // If there's no match for this reference with a docArchive, we're done!
            throw Abort(.notFound, reason: "No docArchives for this reference")
        }

        let availableDocumentationVersions: [DocumentationPageProcessor.AvailableDocumentationVersion] = ([
            documentationVersions.first { $0.latest == .defaultBranch },
            documentationVersions.first { $0.latest == .preRelease }
        ] + documentationVersions.latestMajorVersions())
            .compactMap { version in
                guard let version = version
                else { return nil }

                // There are versions in `documentationVersions` that have a nil `latest`, but given
                // the filtering above they can be assumed to be release versions for display.
                let versionKind = version.latest ?? .release
                let isLatesStable = version.latest == .release

                return .init(kind: versionKind,
                             reference: "\(version.reference)",
                             docArchives: version.docArchives,
                             isLatestStable: isLatesStable)
            }

        let availableArchives: [DocumentationPageProcessor.AvailableArchive] = documentation.docArchives.map {
            .init(archive: $0, isCurrent: $0.name == archive)
        }

        // Try and parse the page and add our header, but fall back to the unprocessed page if it fails.
        guard let body = awsResponse.body,
              let processor = DocumentationPageProcessor(repositoryOwner: owner,
                                                         repositoryOwnerName: documentation.ownerName,
                                                         repositoryName: repository,
                                                         packageName: documentation.packageName,
                                                         reference: reference,
                                                         referenceLatest: documentation.latest,
                                                         referenceKind: documentation.reference.versionKind,
                                                         availableArchives: availableArchives,
                                                         availableVersions: availableDocumentationVersions,
                                                         updatedAt: documentation.updatedAt,
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
    }

    static func awsResponse(client: Client, owner: String, repository: String, reference: String, fragment: Fragment, path: String) async throws -> ClientResponse {
        let url = try Self.awsDocumentationURL(owner: owner, repository: repository, reference: reference, fragment: fragment, path: path)
        guard let response = try? await Current.fetchDocumentation(client, url) else {
            throw Abort(.notFound)
        }
        guard (200..<399).contains(response.status.code) else {
            // Convert anything that isn't a 2xx or 3xx from AWS into a 404 from us.
            throw Abort(.notFound)
        }
        return response
    }

    static func readme(req: Request) throws -> EventLoopFuture<Node<HTML.BodyContext>> {
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

    static func releases(req: Request) throws -> EventLoopFuture<Node<HTML.BodyContext>> {
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

    static func builds(req: Request) async throws -> HTML {
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

    static func maintainerInfo(req: Request) throws -> EventLoopFuture<HTML> {
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
            case .css, .data, .documentation, .images, .img, .index, .js, .tutorials:
                return URI(string: "\(baseURL)/\(fragment)/\(path)")
            case .faviconIco, .faviconSvg, .themeSettings:
                return path.isEmpty
                ? URI(string: "\(baseURL)/\(fragment)")
                : URI(string: "\(baseURL)/\(path)/\(fragment)")
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


extension PackageController.Fragment: CustomStringConvertible {
    var description: String { rawValue }
}
