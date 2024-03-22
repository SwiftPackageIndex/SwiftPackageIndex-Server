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
    // temporary, hacky docc-proxy
    // default handlers (no ref)
    app.get(":owner", ":repository", "documentation") {
        try await PackageController.defaultDocumentation(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", "documentation", "**") {
        try await PackageController.defaultDocumentation(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", "tutorials", "**") {
        try await PackageController.defaultDocumentation(req: $0, fragment: .tutorials)
    }.excludeFromOpenAPI()

    // targeted handlers (with ref)
    app.get(":owner", ":repository", ":reference", "documentation") {
        try await PackageController.documentation(req: $0)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation", ":archive") {
        try await PackageController.documentation(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "documentation", ":archive", "**") {
        try await PackageController.documentation(req: $0, fragment: .documentation)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconIco)) {
        try await PackageController.documentation(req: $0, fragment: .faviconIco)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.faviconSvg)) {
        try await PackageController.documentation(req: $0, fragment: .faviconSvg)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "css", "**") {
        try await PackageController.documentation(req: $0, fragment: .css)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "data", "**") {
        try await PackageController.documentation(req: $0, fragment: .data)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "images", "**") {
        try await PackageController.documentation(req: $0, fragment: .images)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "img", "**") {
        try await PackageController.documentation(req: $0, fragment: .img)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "index", "**") {
        try await PackageController.documentation(req: $0, fragment: .index)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "js", "**") {
        try await PackageController.documentation(req: $0, fragment: .js)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.linkablePaths)) {
        try await PackageController.documentation(req: $0, fragment: .linkablePaths)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", .fragment(.themeSettings)) {
        try await PackageController.documentation(req: $0, fragment: .themeSettings)
    }.excludeFromOpenAPI()
    app.get(":owner", ":repository", ":reference", "tutorials", "**") {
        try await PackageController.documentation(req: $0, fragment: .tutorials)
    }.excludeFromOpenAPI()
}


func docRoutesDev(_ app: Application) throws {
    try docRoutes(app)
}


private extension PathComponent {
    static func fragment(_ fragment: PackageController.Fragment) -> Self { "\(fragment)" }
}
