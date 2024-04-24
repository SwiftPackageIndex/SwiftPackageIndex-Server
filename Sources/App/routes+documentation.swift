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
        try await PackageController.documentationRedirect(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", "documentation", "**") {
        try await PackageController.documentationRedirect(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", "tutorials", "**") {
        try await PackageController.documentationRedirect(req: $0, fragment: .tutorials)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "documentation") {
        try await PackageController.documentationRedirect(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation") { req in
        guard let ref = req.parameters.get("reference").map(Reference.init) else { throw Abort(.notFound) }
        return try await PackageController.documentationRedirect(req: req, fragment: .documentation, reference: ref)
    }.excludeFromOpenAPI()

    // Stable URLs with current (~) reference.
    app.get(":owner", ":repository", .current, "documentation", ":archive") {
        try await PackageController.documentation(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "documentation", ":archive", "**") {
        try await PackageController.documentation(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, .fragment(.faviconIco)) {
        try await PackageController.documentation(req: $0, fragment: .faviconIco)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, .fragment(.faviconSvg)) {
        try await PackageController.documentation(req: $0, fragment: .faviconSvg)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "css", "**") {
        try await PackageController.documentation(req: $0, fragment: .css)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "data", "**") {
        try await PackageController.documentation(req: $0, fragment: .data)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "images", "**") {
        try await PackageController.documentation(req: $0, fragment: .images)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "img", "**") {
        try await PackageController.documentation(req: $0, fragment: .img)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "index", "**") {
        try await PackageController.documentation(req: $0, fragment: .index)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "js", "**") {
        try await PackageController.documentation(req: $0, fragment: .js)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, .fragment(.linkablePaths)) {
        try await PackageController.documentation(req: $0, fragment: .linkablePaths)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, .fragment(.themeSettings)) {
        try await PackageController.documentation(req: $0, fragment: .themeSettings)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", .current, "tutorials", "**") {
        try await PackageController.documentation(req: $0, fragment: .tutorials)
    }.excludeFromOpenAPI()

    // Version specific documentation - No index and non-canonical URLs with a specific reference.
    app.get(":owner", ":repository", ":reference", "documentation", ":archive") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .documentation, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation", ":archive", "**") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .documentation, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconIco)) { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .faviconIco, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconSvg)) { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .faviconSvg, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "css", "**") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .css, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "data", "**") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .data, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "images", "**") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .images, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "img", "**") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .img, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "index", "**") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .index, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "js", "**") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .js, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.linkablePaths)) { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .linkablePaths, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.themeSettings)) { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .themeSettings, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "tutorials", "**") { req in
        guard let ref = req.parameters.get("reference") else { throw Abort(.notFound) }
        return try await PackageController.documentation(req: req, reference: ref, fragment: .tutorials, rewriteStrategy: .toReference(ref))
    }.excludeFromOpenAPI()
}


private extension PathComponent {
    static func fragment(_ fragment: PackageController.Fragment) -> Self { "\(fragment)" }
}
