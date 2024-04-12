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
    app.get(":owner", ":repository", ":reference", "documentation") {
        let lookup: Request.LookupStrategy = $0.isCurrentReference ? .unspecified : .noArchive
        return try await PackageController.documentationRedirect($0.getRedirectRoute(lookup), fragment: .documentation)
    }.excludeFromOpenAPI()

    // Stable URLs with reference (real reference or ~)
    app.get(":owner", ":repository", ":reference", "documentation", ":archive") {
        let route = try await $0.getDocRoute(fragment: .documentation)
#warning("check if we can derive rewriteStrategy from docVersion")
        let rewriteStrategy: DocumentationPageProcessor.RewriteStrategy = $0.isCurrentReference
        ? .current(fromReference: route.docVersion.reference)
        : .toReference(route.docVersion.reference)
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: rewriteStrategy)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation", ":archive", "**") {
        let route = try await $0.getDocRoute(fragment: .documentation)
#warning("check if we can derive rewriteStrategy from docVersion")
        let rewriteStrategy: DocumentationPageProcessor.RewriteStrategy = $0.isCurrentReference
        ? .current(fromReference: route.docVersion.reference)
        : .toReference(route.docVersion.reference)
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: rewriteStrategy)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconIco)) {
        let route = try await $0.getDocRoute(fragment: .faviconIco)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconSvg)) {
        let route = try await $0.getDocRoute(fragment: .faviconSvg)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "css", "**") {
        let route = try await $0.getDocRoute(fragment: .css)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "data", "**") {
        let route = try await $0.getDocRoute(fragment: .data)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "images", "**") {
        let route = try await $0.getDocRoute(fragment: .images)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "img", "**") {
        let route = try await $0.getDocRoute(fragment: .img)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "index", "**") {
        let route = try await $0.getDocRoute(fragment: .index)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "js", "**") {
        let route = try await $0.getDocRoute(fragment: .js)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.linkablePaths)) {
        let route = try await $0.getDocRoute(fragment: .linkablePaths)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.themeSettings)) {
        let route = try await $0.getDocRoute(fragment: .themeSettings)
        return try await PackageController.documentation(req: $0, route: route)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "tutorials", "**") {
        let lookup: Request.LookupStrategy = $0.isCurrentReference ? .unspecified : .fullySpecified
        let route = try await $0.getDocRoute(lookup, fragment: .tutorials)
#warning("check if we can derive rewriteStrategy from docVersion")
        let rewriteStrategy: DocumentationPageProcessor.RewriteStrategy = $0.isCurrentReference
        ? .current(fromReference: route.docVersion.reference)
        : .toReference(route.docVersion.reference)
        return try await PackageController.documentation(req: $0, route: route, rewriteStrategy: rewriteStrategy)
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
        case fullySpecified
        case noArchive
        case noReference
        case unspecified
    }

    func getRedirectRoute(_ strategy: LookupStrategy) async throws -> RedirectDocRoute {
        guard let owner = parameters.get("owner"),
              let repository = parameters.get("repository")
        else { throw Abort(.badRequest) }

        let anchor = url.fragment.map { "#\($0)"} ?? ""
        let path = parameters.getCatchall().joined(separator: "/").lowercased() + anchor

        let target: DocumentationTarget? = try await {
            switch strategy {
                case .fullySpecified:
                    // For sake of completeness - a fully specified route should not be hit from a redirect handler
                    guard let archive = parameters.get("archive"),
                          let ref = parameters.get("reference")
                    else { throw Abort(.badRequest) }
                    return .internal(reference: ref, archive: archive)

                case .noArchive:
                    guard let ref = parameters.get("reference").map(Reference.init) else { throw Abort(.badRequest) }
                    return try await DocumentationTarget.query(on: db, owner: owner, repository: repository, reference: ref)
                    
                case .noReference:
                    guard let archive = parameters.get("archive") else { throw Abort(.badRequest) }
                    let target = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)
                    if target?.internal?.archive != archive.lowercased() { throw Abort(.notFound) }
                    return target
                    
                case .unspecified:
                    return try await DocumentationTarget.query(on: db, owner: owner, repository: repository)
            } 
        }()
        
        guard let target else { throw Abort(.notFound) }

        return .init(owner: owner, repository: repository, target: target, path: path)
    }
    
    func getDocRoute(_ strategy: LookupStrategy? = nil, fragment: DocRoute.Fragment) async throws -> DocRoute {
        guard let owner = parameters.get("owner"),
              let repository = parameters.get("repository")
        else { throw Abort(.badRequest) }
        let strategy = strategy ?? (isCurrentReference ? .noReference : .fullySpecified)

        switch strategy {
            case .fullySpecified:
                guard let ref = parameters.get("reference") else { throw Abort(.badRequest) }
                let archive = parameters.get("archive")
                if fragment.requiresArchive && archive == nil { throw Abort(.badRequest) }
                let pathElements = parameters.pathElements(for: fragment, archive: archive)
                return .init(owner: owner, repository: repository, docVersion: .reference(ref), fragment: fragment, pathElements: pathElements)
                
            case .noArchive:
                // This route is not currently set up to go through getDocRoute - it would be handled by getRedirectRoute
                throw Abort(.badRequest)

            case .noReference:
                guard let archive = parameters.get("archive") else { throw Abort(.badRequest) }
                guard let params = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)?.internal
                else { throw Abort(.notFound) }
                guard archive.lowercased() == params.archive.lowercased() else { throw Abort(.notFound) }
                let pathElements = parameters.pathElements(for: fragment, archive: archive)
                return DocRoute(owner: owner, repository: repository, fragment: fragment, docVersion: .current(referencing: params.reference), pathElements: pathElements)
                
            case .unspecified:
                guard let params = try await DocumentationTarget.query(on: db, owner: owner, repository: repository)?.internal
                else { throw Abort(.notFound) }
                let pathElements = parameters.pathElements(for: fragment, archive: params.archive)
                return DocRoute(owner: owner, repository: repository, docVersion: .current(referencing: params.reference), fragment: fragment, pathElements: pathElements)
        }
    }
    
    var isCurrentReference: Bool {
        parameters.get("reference") == String.current
    }
}
