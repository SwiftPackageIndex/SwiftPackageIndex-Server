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

import Dependencies
import Vapor


func docRoutes(_ app: Application) throws {
    // Underspecified documentation routes - these routes lack the reference, the archive, or both.
    // Therefore, these parts need to be queried from the database and the request will be
    // redirected to the fully formed documentation URL.
    app.get(":owner", ":repository", "documentation") { req -> Response in
        req.redirect(to: SiteURL.relativeURL(for: try await req.getDocRedirect(), fragment: .documentation))
    }
    app.get(":owner", ":repository", "documentation", "**") { req -> Response in
        req.redirect(to: SiteURL.relativeURL(for: try await req.getDocRedirect(), fragment: .documentation))
    }
    app.get(":owner", ":repository", "tutorials", "**") { req -> Response in
        req.redirect(to: SiteURL.relativeURL(for: try await req.getDocRedirect(), fragment: .tutorials))
    }
    app.get(":owner", ":repository", ":reference", "documentation") { req -> Response in
        req.redirect(to: SiteURL.relativeURL(for: try await req.getDocRedirect(), fragment: .documentation))
    }

    // Stable URLs with reference (real reference or ~)
    app.get(":owner", ":repository", ":reference", "documentation", ":archive") {
        let route = try await $0.getDocRoute(fragment: .documentation)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "documentation", ":archive", "**") {
        let route = try await $0.getDocRoute(fragment: .documentation)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", .fragment(.faviconIco)) {
        let route = try await $0.getDocRoute(fragment: .faviconIco)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", .fragment(.faviconSvg)) {
        let route = try await $0.getDocRoute(fragment: .faviconSvg)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "css", "**") {
        let route = try await $0.getDocRoute(fragment: .css)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "data", "**") {
        let route = try await $0.getDocRoute(fragment: .data)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "images", "**") {
        let fragment: DocRoute.Fragment = $0.parameters.hasSuffix(".svg", caseInsensitive: true) ? .svgImages : .images
        let route = try await $0.getDocRoute(fragment: fragment)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "img", "**") {
        let fragment: DocRoute.Fragment = $0.parameters.hasSuffix(".svg", caseInsensitive: true) ? .svgImg : .img
        let route = try await $0.getDocRoute(fragment: fragment)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "index", "**") {
        let route = try await $0.getDocRoute(fragment: .index)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "js", "**") {
        let route = try await $0.getDocRoute(fragment: .js)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", .fragment(.linkablePaths)) {
        let route = try await $0.getDocRoute(fragment: .linkablePaths)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", .fragment(.themeSettings)) {
        let route = try await $0.getDocRoute(fragment: .themeSettings)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "tutorials", "**") {
        let route = try await $0.getDocRoute(fragment: .tutorials)
        return try await PackageController.documentation(req: $0, route: route)
    }
    app.get(":owner", ":repository", ":reference", "videos", "**") {
        let route = try await $0.getDocRoute(fragment: .videos)
        return try await PackageController.documentation(req: $0, route: route)
    }
}


private extension PathComponent {
    static func fragment(_ fragment: DocRoute.Fragment) -> Self { "\(fragment)" }
}


private extension Parameters {
    func pathElements(for fragment: DocRoute.Fragment, archive: String? = nil) -> [String] {
        switch fragment {
            case .data, .documentation, .tutorials:
                // DocC lowercases "target" names in URLs. Since these routes can also
                // appear in user generated content which might use uppercase spelling, we need
                // to lowercase the input in certain cases.
                // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2168
                // and https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2172
                // for details.
                // ⚠️ DO NOT CHANGE THE LINE AFTER THIS COMMENT WITHOUT REVIEWING ISSUE
                // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/3021
                // AND THE FIX
                // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/pull/3039
                return ([archive].compactMap { $0 } + getCatchall()).map { $0.lowercased() }
            case .css, .faviconIco, .faviconSvg, .images, .img, .index, .js, .linkablePaths, .themeSettings, .svgImages, .svgImg, .videos:
                return getCatchall()
        }
    }

    func hasSuffix(_ suffix: String, caseInsensitive: Bool) -> Bool {
        if caseInsensitive {
            return getCatchall().last?.lowercased().hasSuffix(suffix.lowercased()) ?? false
        } else {
            return getCatchall().last?.hasSuffix(suffix) ?? false
        }
    }
}


struct DocRedirect {
    var owner: String
    var repository: String
    var target: DocumentationTarget
    var path: String
}


extension Request {
    func getDocRedirect() async throws -> DocRedirect {
        guard let owner = parameters.get("owner"),
              let repository = parameters.get("repository")
        else { throw Abort(.badRequest) }

        let anchor = url.fragment.map { "#\($0)"} ?? ""
        let path = parameters.getCatchall().joined(separator: "/").lowercased() + anchor

        let target: DocumentationTarget?
        switch parameters.get("reference") {
            case let .some(ref):
                if ref == .current {
                    target = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)
                } else {
                    target = try await DocumentationTarget.query(on: db, owner: owner, repository: repository,
                                                                 docVersion: .reference(ref))
                }

            case .none:
                target = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)
        }
        guard let target else { throw Abort(.notFound) }

        return .init(owner: owner, repository: repository, target: target, path: path)
    }

    func getDocRoute(fragment: DocRoute.Fragment) async throws -> DocRoute {
        guard let owner = parameters.get("owner"),
              let repository = parameters.get("repository"),
              let reference = parameters.get("reference")
        else { throw Abort(.badRequest) }
        let archive = parameters.get("archive")
        if fragment.requiresArchive && archive == nil { throw Abort(.badRequest) }
        let pathElements = parameters.pathElements(for: fragment, archive: archive)

        @Dependency(\.environment) var environment

        let docVersion = try await { () -> DocVersion in
            if reference == String.current {
                @Dependency(\.currentReferenceCache) var currentReferenceCache
                if let ref = await currentReferenceCache.get(owner: owner, repository: repository) {
                    return .current(referencing: ref)
                }

                guard let params = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)?.internal
                else { throw Abort(.notFound) }

                await currentReferenceCache.set(owner: owner, repository: repository, reference: "\(params.docVersion)")
                return .current(referencing: "\(params.docVersion)")
            } else {
                return .reference(reference)
            }
        }()

        return DocRoute(owner: owner, repository: repository, docVersion: docVersion, fragment: fragment, pathElements: pathElements)
    }
}


private extension SiteURL {
    static func relativeURL(for docRedirect: DocRedirect, fragment: DocRoute.Fragment) -> String {
        relativeURL(owner: docRedirect.owner,
                    repository: docRedirect.repository,
                    documentation: docRedirect.target,
                    fragment: fragment,
                    path: docRedirect.path)
    }
}


extension Swift.Never: Vapor.ResponseEncodable {
    // Temporary, to avoid warning in crash route
    public func encodeResponse(for request: Vapor.Request) -> NIOCore.EventLoopFuture<Vapor.Response> {
        request.eventLoop.makeSucceededFuture(.init(status: .ok))
    }
}
