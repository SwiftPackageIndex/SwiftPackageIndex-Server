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
                                 redirectType: .permanent)
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

    static func documentation(req: Request, route: DocRoute) async throws -> Response {
        let res: ClientResponse
        do {
            res = try await awsResponse(client: req.client, route: route)
        } catch {
            print(error)
            throw error
        }

        switch route.fragment {
            case .documentation, .tutorials:
                let documentationMetadata = try await DocumentationMetadata
                    .query(on: req.db, owner: route.owner, repository: route.repository)

                return try await documentationResponse(
                    req: req,
                    route: route,
                    awsResponse: res,
                    documentationMetadata: documentationMetadata
                )

            case .css, .data, .faviconIco, .faviconSvg, .images, .img, .index, .js, .linkablePaths, .themeSettings:
                return try await res.encodeResponse(
                    status: .ok,
                    headers: req.headers
                        .replacingOrAdding(name: .contentType, value: route.fragment.contentType)
                        .replacingOrAdding(name: .cacheControl, value: "no-transform"),
                    for: req
                )
        }
    }

    static func documentationResponse(req: Request,
                                      route: DocRoute,
                                      awsResponse: ClientResponse,
                                      documentationMetadata: DocumentationMetadata) async throws -> Response {
        guard let documentation = documentationMetadata.versions[reference: route.docVersion.reference]
        else {
            // If there's no match for this reference with a docArchive, we're done!
            throw Abort(.notFound, reason: "No docArchives for this reference")
        }

        let availableDocumentationVersions: [DocumentationPageProcessor.AvailableDocumentationVersion] = ([
            documentationMetadata.versions.first { $0.latest == .defaultBranch },
            documentationMetadata.versions.first { $0.latest == .preRelease }
        ] + documentationMetadata.versions.latestMajorVersions())
            .compactMap { version in
                guard let version = version
                else { return nil }

                // There are versions in `documentationVersions` that have a nil `latest`, but given
                // the filtering above they can be assumed to be release versions for display.
                let versionKind = version.latest ?? .release
                let isLatestStable = version.latest == .release

                return .init(kind: versionKind,
                             reference: "\(version.reference)",
                             docArchives: version.docArchives,
                             isLatestStable: isLatestStable)
            }

        let availableArchives: [DocumentationPageProcessor.AvailableArchive] = documentation.docArchives.map {
            .init(archive: $0, isCurrent: $0.name == route.archive)
        }

        let canonicalUrl = Self.canonicalDocumentationUrl(fromUrlPath: "\(req.url)",
                                                          owner: documentationMetadata.owner,
                                                          repository: documentationMetadata.repository)

        // Try and parse the page and add our header, but fall back to the unprocessed page if it fails.
        guard let body = awsResponse.body,
              let processor = DocumentationPageProcessor(repositoryOwner: route.owner,
                                                         repositoryOwnerName: documentation.ownerName,
                                                         repositoryName: route.repository,
                                                         packageName: documentation.packageName,
                                                         docVersion: route.docVersion,
                                                         referenceLatest: documentation.latest,
                                                         referenceKind: documentation.reference.versionKind,
                                                         canonicalUrl: canonicalUrl,
                                                         availableArchives: availableArchives,
                                                         availableVersions: availableDocumentationVersions,
                                                         updatedAt: documentation.updatedAt,
                                                         rawHtml: body.asString())
        else {
            return try await awsResponse.encodeResponse(
                status: .ok,
                headers: req.headers.replacingOrAdding(name: .contentType,
                                                       value: route.contentType),
                for: req
            )
        }

        return try await processor.processedPage.encodeResponse(
            status: .ok,
            headers: req.headers.replacingOrAdding(name: .contentType,
                                                   value: route.contentType),
            for: req
        )
    }

    static func awsResponse(client: Client, route: DocRoute) async throws -> ClientResponse {
        let url = try Self.awsDocumentationURL(route: route)
        guard let response = try? await Current.fetchDocumentation(client, url) else {
            throw Abort(.notFound)
        }
        guard (200..<399).contains(response.status.code) else {
            // Convert anything that isn't a 2xx or 3xx from AWS into a 404 from us.
            throw Abort(.notFound)
        }
        return response
    }

    static func siteMap(req: Request) async throws -> SiteMap {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else { throw Abort(.notFound) }

        // Temporarily limit documentation in package sitemaps with an allow list to convince
        // Google we have not been hacked! This should take us from ~460,000 URLs to < 20,000.
        let allowList = [
            // Page is not indexed: Crawled - currently not indexed
            (owner: "swiftpackageindex", repository: "semanticversion"), // 60 urls
            (owner: "liuliu", repository: "dflat"), // 1,039 urls
            (owner: "onevcat", repository: "kingfisher"), // 1,674 urls
            (owner: "apple", repository: "swift-docc"), // 5,404 urls
            // Page is not indexed: Discovered – currently not indexed
            (owner: "siteline", repository: "swiftui-introspect"), // 600 urls
            (owner: "apple", repository: "swift-collections"), // 951 urls
            // First expansion after successful indexing - Total expansion of 13380 urls
            (owner: "alexslee", repository: "FlexSeal"), // 525 urls
            (owner: "Northwind-swift", repository: "NorthwindSwiftData"), // 555 urls
            (owner: "orlandos-nl", repository: "MongoKitten"), // 521 urls
            (owner: "StanfordBDHG", repository: "OMHModels"), // 696 urls
            (owner: "gonzalezreal", repository: "NetworkImage"), // 643 urls
            (owner: "AudioKit", repository: "Waveform"), // 620 urls
            (owner: "GoodHatsLLC", repository: "StateTree"), // 584 urls
            (owner: "jordanbaird", repository: "ColorWellKit"), // 714 urls
            (owner: "jordanbaird", repository: "ColorWell"), // 726 urls
            (owner: "apple", repository: "swift-nio-extras"), // 699 urls
            (owner: "edonv", repository: "QLThumbnail"), // 639 urls
            (owner: "edonv", repository: "SwiftUIMessage"), // 983 urls
            (owner: "apple", repository: "swift-openapi-runtime"), // 587 urls
            (owner: "lorenzofiamingo", repository: "swiftui-cached-async-image"), // 608 urls
            (owner: "bdrelling", repository: "Structure"), // 937 urls
            (owner: "jagreenwood", repository: "open-weather-kit"), // 554 urls
            (owner: "marcoarment", repository: "Blackbird"), // 687 urls
            (owner: "dirtyhenry", repository: "swift-blocks"), // 947 urls
            (owner: "FlineDev", repository: "HandySwift"), // 533 urls
            (owner: "FelixHerrmann", repository: "swift-package-list"), // 622 urls
        ]

        // For future expansion of the above list, this query is useful:
        // -----------------
        // SELECT
        //   p.id,
        //   r.name,
        //   r.owner,
        //   v.reference,
        //   d.linkable_paths_count
	    //   '(owner: "' || r.owner || '", repository: "' || r.name || '"), // ' || d.linkable_paths_count || ' urls'
        // FROM
        //   packages p
        //   INNER JOIN repositories r ON p.id = r.package_id
        //   INNER JOIN versions v ON p.id = v.package_id
        //   INNER JOIN builds b ON v.id = b.version_id
        //   INNER JOIN doc_uploads d ON b.id = d.build_id
        // WHERE
        //   v.latest = 'default_branch'
        //   AND d.linkable_paths_count BETWEEN 500 AND 1000
        // ORDER BY
        //   random()
        // LIMIT 20;
        // -----------------

        let packageResult = try await PackageResult.query(on: req.db, owner: owner, repository: repository)
        let urls = if allowList.contains(where: {
            owner.lowercased() == $0.owner.lowercased() &&
            repository.lowercased() == $0.repository.lowercased()
        }) {
            await linkablePathUrls(client: req.client, packageResult: packageResult)
        } else {
            [String]()
        }

        return try await SiteMapController.package(owner: packageResult.repository.owner,
                                                   repository: packageResult.repository.name,
                                                   lastActivityAt: packageResult.repository.lastActivityAt,
                                                   linkablePathUrls: urls)
    }

    static func linkablePathUrls(client: Client, packageResult: PackageResult) async -> [String] {
        guard let canonicalTarget = [packageResult.defaultBranchVersion.model,
                                     packageResult.preReleaseVersion?.model,
                                     packageResult.releaseVersion?.model].canonicalDocumentationTarget(),
              case let DocumentationTarget.internal(reference, _) = canonicalTarget,
              let owner = packageResult.repository.owner,
              let repository = packageResult.repository.name
        else {
            // If we can not get a definitively correct canonical URL because one of these things
            // is not available, it is better not to include canonical documentation URLs.
            return []
        }
        let pathEncodedReference = reference.pathEncoded

        do {
            let route = DocRoute(owner: owner, repository: repository, docVersion: .reference(pathEncodedReference), fragment: .linkablePaths)
            let awsResponse = try await awsResponse(client: client, route: route)
            guard let body = awsResponse.body else { return [] }

            let baseUrl = SiteURL.package(.value(owner), .value(repository), .none).absoluteURL()
            return try JSONDecoder()
                .decode([String].self, from: body)
                .map { "\(baseUrl)/\(pathEncodedReference)\($0)"  }
        } catch {
            // Errors here should *never* break the site map. Instead, they should return no
            // linkable paths. The most likely cause of an error here is either a 4xx from
            // the `awsResponse` (meaning there is no `linkable-paths.json` on the server),
            // or a JSON decoding error. Both should result in a blank set of URLs.
            return []
        }
    }

    static func readme(req: Request) async throws -> Node<HTML.BodyContext> {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            throw Abort(.notFound)
        }

        let pkg = try await Joined<Package, Repository>
            .query(on: req.db, owner: owner, repository: repository).get()

        // For repositories that have no README file at all.
        guard let readmeHtmlUrl = pkg.repository?.readmeHtmlUrl else {
            return PackageReadme.View(model: .noReadme).document()
        }

        do {
            let readme = try await Current.fetchS3Readme(req.client, owner, repository)
            guard let branch = pkg.repository?.defaultBranch else {
                return PackageReadme.View(model: .cacheLookupFailed(url: readmeHtmlUrl)).document()
            }
            return PackageReadme.View(model: .init(url: readmeHtmlUrl,
                                                   repositoryOwner: owner,
                                                   repositoryName: repository,
                                                   defaultBranch: branch,
                                                   readme: readme)).document()
        } catch {
            if let repo = pkg.repository {
                repo.s3Readme = .error("failed to fetch ")
                try await repo.update(on: req.db)
            }
            return PackageReadme.View(model: .cacheLookupFailed(url: readmeHtmlUrl)).document()
        }
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

    static func maintainerInfo(req: Request) async throws -> HTML {
        guard
            let owner = req.parameters.get("owner"),
            let repository = req.parameters.get("repository")
        else {
            throw Abort(.notFound)
        }

        guard let result = try await Joined3<Package, Repository, Version>
            .query(on: req.db, owner: owner, repository: repository, version: .defaultBranch)
            .field(Package.self, \.$score)
            .field(Package.self, \.$scoreDetails)
            .field(Repository.self, \.$owner)
            .field(Repository.self, \.$ownerName)
            .field(Repository.self, \.$name)
            .field(Version.self, \.$packageName)
            .first()
        else { throw Abort(.notFound) }

        guard let repositoryOwner = result.repository.owner,
              let repositoryName = result.repository.name else {
            throw Abort(.notFound)
        }

        let model = MaintainerInfoIndex.Model(
            packageName: result.version.packageName ?? repositoryName,
            repositoryOwner: repositoryOwner,
            repositoryOwnerName: result.repository.ownerName ?? repositoryOwner,
            repositoryName: repositoryName,
            score: result.model.score,
            scoreDetails: result.model.scoreDetails
        )

        return MaintainerInfoIndex.View(path: req.url.path, model: model).document()
    }
}


extension PackageController {

    enum ShowModel {
        case packageAvailable(API.PackageController.GetRoute.Model, API.PackageSchema)
        case packageMissing(MissingPackage.Model)
        case packageDoesNotExist

        init(db: Database, owner: String, repository: String) async throws {
            do {
                let (model, schema) = try await API.PackageController.GetRoute
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
    static func awsDocumentationURL(route: DocRoute) throws -> URI {
        guard let bucket = Current.awsDocsBucket() else {
            throw AppError.envVariableNotSet("AWS_DOCS_BUCKET")
        }

        let baseURLHost = "\(bucket).s3-website.us-east-2.amazonaws.com"
        let baseURL = "http://\(baseURLHost)/\(route.baseURL)"
        let path = route.path

        switch route.fragment {
            case .css, .data, .documentation, .images, .img, .index, .js, .tutorials:
                return URI(string: "\(baseURL)/\(route.fragment)/\(path)")
            case .faviconIco, .faviconSvg, .themeSettings:
                return path.isEmpty
                ? URI(string: "\(baseURL)/\(route.fragment)")
                : URI(string: "\(baseURL)/\(path)/\(route.fragment)")
            case .linkablePaths:
                return URI(string: "\(baseURL)/\(route.fragment)")
        }
    }
}

extension PackageController {
    static func canonicalDocumentationUrl(fromUrlPath urlPath: String,
                                          owner: String?,
                                          repository: String?) -> String? {
        guard let owner, let repository else { return nil }

        var urlComponents = urlPath.components(separatedBy: "/")

        guard urlComponents.prefix(3) == ["", owner, repository], urlComponents.count > 4
        else { return nil }

        // Replace the reference with the "current" tilde character regardless of the incoming reference.
        urlComponents[3] = "~"
        return Current.siteURL() + urlComponents.joined(by: "/")
    }
}

private extension HTTPHeaders {
    func replacingOrAdding(name: Name, value: String) -> Self {
        var headers = self
        headers.replaceOrAdd(name: name, value: value)
        return headers
    }
}
