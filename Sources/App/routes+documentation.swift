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


import Vapor


func docRoutes(_ app: Application) throws {
    // Underspecified documentation routes - these routes lack the reference, the archive, or both.
    // Therefore, these parts need to be queried from the database and the request will be
    // redirected to the fully formed documentation URL.
    app.get(":owner", ":repository", "documentation") {
        try await PackageController.documentationRedirect($0.getRedirectRoute(.unspecified), fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", "documentation", "**") {
        try await PackageController.documentationRedirect($0.getRedirectRoute(.unspecified), fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", "tutorials", "**") {
        try await PackageController.documentationRedirect($0.getRedirectRoute(.unspecified), fragment: .tutorials)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "documentation") {
        try await PackageController.documentationRedirect($0.getRedirectRoute(.unspecified), fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation") {        
        try await PackageController.documentationRedirect($0.getRedirectRoute(.referenceOnly), fragment: .documentation)
    }.excludeFromOpenAPI()

    // Stable URLs with current (~) reference.
    app.get(":owner", ":repository", .current, "documentation", ":archive") {
        let route = try await $0.getDocRoute(.archiveOnly, fragment: .documentation)
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .current(fromReference: route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "documentation", ":archive", "**") {
        let route = try await $0.getDocRoute(.archiveOnly, fragment: .documentation)
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .current(fromReference: route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, .fragment(.faviconIco)) {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .faviconIco) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, .fragment(.faviconSvg)) {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .faviconSvg) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "css", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .css) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "data", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .data) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "images", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .images) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "img", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .img) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "index", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .index) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "js", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .js) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, .fragment(.linkablePaths)) {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .linkablePaths) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, .fragment(.themeSettings)) {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .themeSettings) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "tutorials", "**") {
        let route = try await $0.getDocRoute(.unspecified, fragment: .tutorials)
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .current(fromReference: route.docVersion.reference))
    }.excludeFromOpenAPI()

    // Version specific documentation - No index and non-canonical URLs with a specific reference.
    app.get(":owner", ":repository", ":reference", "documentation", ":archive") {
#warning("throw badRequest instead of notFound in all other .get()s")
        guard let archive = $0.parameters.get("archive") else { throw Abort(.badRequest) }
        guard let route = DocRoute(parameters: $0.parameters, fragment: .documentation, pathElements: $0.parameters.pathElements(for: .documentation, archive: archive))
        else { throw Abort(.badRequest) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation", ":archive", "**") {
        guard let archive = $0.parameters.get("archive") else { throw Abort(.badRequest) }
        guard let route = DocRoute(parameters: $0.parameters, fragment: .documentation, pathElements: $0.parameters.pathElements(for: .documentation, archive: archive))
        else { throw Abort(.badRequest) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconIco)) {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .faviconIco) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconSvg)) {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .faviconSvg) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "css", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .css) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "data", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .data) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "images", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .images) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "img", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .img) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "index", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .index) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "js", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .js) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.linkablePaths)) {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .linkablePaths) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.themeSettings)) {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .themeSettings) else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "tutorials", "**") {
        guard let route = DocRoute(parameters: $0.parameters, fragment: .tutorials) else { throw Abort(.badRequest) }
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: .toReference(route.docVersion.reference))
    }.excludeFromOpenAPI()
}


private extension PathComponent {
    static func fragment(_ fragment: DocRoute.Fragment) -> Self { "\(fragment)" }
}


#warning("move this or make it private")
extension Parameters {
    func pathElements(for fragment: DocRoute.Fragment, archive: String? = nil) -> [String] {
        let catchall = {
            var p = self
            return p.getCatchall()
        }()
        switch fragment {
            case .data, .documentation, .tutorials:
                // DocC lowercases "target" names in URLs. Since these routes can also
                // appear in user generated content which might use uppercase spelling, we need
                // to lowercase the input in certain cases.
                // See https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2168
                // and https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2172
                // for details.
                return ([archive].compacted() + catchall).map { $0.lowercased() }
            case .css, .faviconIco, .faviconSvg, .images, .img, .index, .js, .linkablePaths, .themeSettings:
                return catchall
        }
    }
}
 
#warning("move this or make it private")
extension Request {
    struct RedirectDocRoute {
        var owner: String
        var repository: String
        var target: DocumentationTarget
        var path: String
    }

    enum LookupStrategy {
        case archiveOnly
        case referenceOnly
        case unspecified
    }

    func getRedirectRoute(_ strategy: LookupStrategy) async throws -> RedirectDocRoute {
        guard let owner = parameters.get("owner"),
              let repository = parameters.get("repository")
        else { throw Abort(.badRequest) }

        let anchor = url.fragment.map { "#\($0)"} ?? ""
        let path = parameters.getCatchall().joined(separator: "/").lowercased() + anchor

        let target = try await {
            switch strategy {
                case .archiveOnly:
                    guard let archive = parameters.get("archive") else { throw Abort(.badRequest) }
                    let target = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)
                    if target?.internal?.archive != archive.lowercased() { throw Abort(.notFound) }
                    return target
                case .referenceOnly:
                    guard let ref = parameters.get("reference").map(Reference.init) else { throw Abort(.badRequest) }
                    return try await DocumentationTarget.query(on: db, owner: owner, repository: repository, reference: ref)
                case .unspecified:
                    return try await DocumentationTarget.query(on: db, owner: owner, repository: repository)
            } 
        }()
        
        guard let target else { throw Abort(.notFound) }

        return .init(owner: owner, repository: repository, target: target, path: path)
    }
    
    func getDocRoute(_ strategy: LookupStrategy, fragment: DocRoute.Fragment) async throws -> DocRoute {
        guard let owner = parameters.get("owner"),
              let repository = parameters.get("repository")
        else { throw Abort(.badRequest) }

        switch strategy {
            case .archiveOnly:
                guard let archive = parameters.get("archive") else { throw Abort(.badRequest) }
                guard let params = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)?.internal
                else { throw Abort(.notFound) }
                guard archive.lowercased() == params.archive.lowercased() else { throw Abort(.notFound) }
                let pathElements = parameters.pathElements(for: fragment, archive: archive)
                return DocRoute(owner: owner, repository: repository, fragment: fragment, docVersion: .current(referencing: params.reference), pathElements: pathElements)

            case .referenceOnly:
                // This route is not currently set up to go through getDocRoute - it would be handled by getRedirectRoute
                throw Abort(.badRequest)

            case .unspecified:
                guard let params = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)?.internal
                else { throw Abort(.notFound) }
                let pathElements = parameters.pathElements(for: fragment, archive: params.archive)
                return DocRoute(owner: owner, repository: repository, docVersion: .current(referencing: params.reference), fragment: fragment, pathElements: pathElements)
        }
    }
}
