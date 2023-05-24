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
import Metrics
import Plot
import Prometheus
import Vapor
import VaporToOpenAPI


func routes(_ app: Application) throws {
    do {  // home page
        app.get { req in
            let model = try await HomeIndex.Model.query(database: req.db)
            return HomeIndex.View(path: req.url.path, model: model).document()
        }.excludeFromOpenAPI()
    }

    do {  // static pages
        app.get(SiteURL.addAPackage.pathComponents) { req in
            MarkdownPage(path: req.url.path, "add-a-package.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.docs(.builds).pathComponents) { req in
            MarkdownPage(path: req.url.path, "docs/builds.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.faq.pathComponents) { req in
            MarkdownPage(path: req.url.path, "faq.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.packageCollections.pathComponents) { req in
            MarkdownPage(path: req.url.path, "package-collections.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.privacy.pathComponents) { req in
            MarkdownPage(path: req.url.path, "privacy.md").document()
        }.excludeFromOpenAPI()

        app.get(SiteURL.tryInPlayground.pathComponents) { req in
            MarkdownPage(path: req.url.path, "try-package.md").document()
        }.excludeFromOpenAPI()
    }

    do {  // package pages
        do {  // temporary, hacky docc-proxy
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
            app.get(":owner", ":repository", ":reference", .fragment(.themeSettings)) {
                try await PackageController.documentation(req: $0, fragment: .themeSettings)
            }.excludeFromOpenAPI()
            app.get(":owner", ":repository", ":reference", "tutorials", "**") {
                try await PackageController.documentation(req: $0, fragment: .tutorials)
            }.excludeFromOpenAPI()
        }

        app.get(SiteURL.package(.key, .key, .none).pathComponents,
                use: PackageController.show).excludeFromOpenAPI()
        app.get(SiteURL.package(.key, .key, .readme).pathComponents,
                use: PackageController.readme).excludeFromOpenAPI()
        app.get(SiteURL.package(.key, .key, .releases).pathComponents,
                use: PackageController.releases).excludeFromOpenAPI()
        app.get(SiteURL.package(.key, .key, .builds).pathComponents,
                use: PackageController.builds).excludeFromOpenAPI()
        app.get(SiteURL.package(.key, .key, .maintainerInfo).pathComponents,
                use: PackageController.maintainerInfo).excludeFromOpenAPI()
    }

    do {  // package collection page
        app.get(SiteURL.packageCollection(.key).pathComponents,
                use: PackageCollectionController.generate).excludeFromOpenAPI()
    }

    do {  // author page
        app.get(SiteURL.author(.key).pathComponents, use: AuthorController.show).excludeFromOpenAPI()
    }

    do {  // keyword page
        app.get(SiteURL.keywords(.key).pathComponents, use: KeywordController.show).excludeFromOpenAPI()
    }

    do { // Build monitor page
        app.get(SiteURL.buildMonitor.pathComponents, use: BuildMonitorController.index).excludeFromOpenAPI()
    }

    do {  // build details page
        app.get(SiteURL.builds(.key).pathComponents, use: BuildController.show).excludeFromOpenAPI()
    }

    do {  // search page
        app.get(SiteURL.search.pathComponents, use: SearchController.show).excludeFromOpenAPI()
    }

    do {  // Supporters
        app.get(SiteURL.supporters.pathComponents, use: SupportersController.show).excludeFromOpenAPI()

    }

    do {  // spi.yml validation page
        app.get(SiteURL.validateSPIManifest.pathComponents, use: ValidateSPIManifestController.show)
            .excludeFromOpenAPI()
        app.post(SiteURL.validateSPIManifest.pathComponents, use: ValidateSPIManifestController.validate)
            .excludeFromOpenAPI()
    }

    do {  // OpenAPI spec
        app.get("openapi", "openapi.json") { req in
            req.application.routes.openAPI(
                info: InfoObject(
                    title: "Swift Package Index API",
                    description: "Swift Package Index API",
                    version: "0.1.1"
                )
            )
        }.excludeFromOpenAPI()
    }

    do {  // api
        
        // public routes
        app.get(SiteURL.api(.version).pathComponents) { req in
            API.Version(version: appVersion ?? "Unknown")
        }
        .openAPI(
            summary: "/api/version",
            description: "Get the site's version.",
            response: API.Version(version: "1.2.3"),
            responseType: .application(.json)
        )

        app.group(APIReportingMiddleware(path: .search)) {
            $0.get(SiteURL.api(.search).pathComponents, use: API.SearchController.get)
                .openAPI(
                    summary: "/api/search",
                    description: "Execute a search.",
                    query: API.SearchController.Query.example,
                    response: Search.Response.example,
                    responseType: .application(.json),
                    errorDescriptions: [
                        400: "Bad request"
                    ]
                )
        }
        
        app.group(APIReportingMiddleware(path: .badge)) {
            $0.get(SiteURL.api(.packages(.key, .key, .badge)).pathComponents,
                   use: API.PackageController.badge)
            .openAPI(
                summary: "/api/packages/{owner}/{repository}/badge",
                description: "Get shields.io badge for the given repository.",
                query: API.PackageController.BadgeQuery.example,
                response: Badge.example,
                responseType: .application(.json),
                errorDescriptions: [
                    400: "Bad request",
                    404: "Not found"
                ])
        }

        // api token protected routes
        app.group(User.APIAuthenticator(), User.guardMiddleware()) {
            $0.groupedOpenAPI(auth: .apiBearerToken).group(tags: []) { protected in
                if Environment.current == .development {
                    protected.group(APIReportingMiddleware(path: .package)) {
                        $0.get("api", "packages", ":owner", ":repository", use: API.PackageController.get)
                            .openAPI(
                                summary: "/api/packages/{owner}/{repository}",
                                description: "Get package details.",
                                response: API.PackageController.GetRoute.Model.example,
                                responseType: .application(.json),
                                errorDescriptions: [
                                    400: "Bad request",
                                    401: "Unauthorized",
                                    404: "Not found"
                                ]
                            )
                    }

                    protected.post(SiteURL.api(.packageCollections).pathComponents,
                                   use: API.PackageCollectionController.generate)
                    .openAPI(
                        summary: "/api/package-collections",
                        description: "Generate a signed package collection.",
                        body: API.PostPackageCollectionDTO.example,
                        response: SignedCollection.example,
                        responseType: .application(.json),
                        errorDescriptions: [
                            400: "Bad request",
                            401: "Unauthorized"
                        ])
                }
            }
        }

        // builder token protected routes
        app.group(User.BuilderAuthenticator(), User.guardMiddleware()) {
            $0.groupedOpenAPI(auth: .builderBearerToken).group(tags: []) { protected in
                protected.on(.POST, SiteURL.api(.versions(.key, .buildReport)).pathComponents,
                             use: API.BuildController.buildReport)
                .openAPI(
                    summary: "/api/versions/{id}/build-report",
                    description: "Send a build report.",
                    body: API.PostBuildReportDTO.example,
                    responseType: .application(.json),
                    errorDescriptions: [
                        400: "Bad request",
                        404: "Not found",
                        409: "Conflict",
                        500: "Internal server error"
                    ]
                )

                protected.on(.POST, SiteURL.api(.builds(.key, .docReport)).pathComponents,
                             use: API.BuildController.docReport)
                .openAPI(
                    summary: "/api/builds/{id}/doc-report",
                    description: "Send a documentation generation report.",
                    body: API.PostDocReportDTO.example,
                    responseType: .application(.json),
                    errorDescriptions: [
                        400: "Bad request",
                        404: "Not found",
                        409: "Conflict",
                        500: "Internal server error"
                    ]
                )
            }
        }
        
    }

    do {  // RSS + Sitemap
        app.get(SiteURL.rssPackages.pathComponents, use: RSSFeed.showPackages)
            .excludeFromOpenAPI()

        app.get(SiteURL.rssReleases.pathComponents, use: RSSFeed.showReleases)
            .excludeFromOpenAPI()

        app.get(SiteURL.siteMap.pathComponents) { req in
            SiteMap.fetchPackages(req.db)
                .map(SiteURL.siteMap)
        }.excludeFromOpenAPI()
    }

    do {  // Metrics
        app.get("metrics") { req -> EventLoopFuture<String> in
            let promise = req.eventLoop.makePromise(of: String.self)
            try MetricsSystem.prometheus().collect(into: promise)
            return promise.futureResult
        }.excludeFromOpenAPI()
    }
}


private extension PathComponent {
    static func fragment(_ fragment: PackageController.Fragment) -> Self { "\(fragment)" }
}
