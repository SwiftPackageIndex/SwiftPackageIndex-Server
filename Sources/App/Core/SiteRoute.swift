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

import URLRouting
import Vapor


enum SiteRoute {
    case api(ApiRoute)
    case addAPackage
    case docs(DocsRoute)
    case faq
    case home
    case keywords(keyword: String, page: Int)
    case package(owner: String, repository: String, route: PackageRoute = .show)
    case packageCollections
    case privacy
    case tryInPlayground(dependencies: String? = nil)

    static let router = OneOf {
        // /api/...
        Route(.case(Self.api)) { Path { "api" }; ApiRoute.router }

        // GET /add-a-package
        Route(.case(Self.addAPackage)) { Path { "add-a-package" } }

        // /docs/...
        Route(.case(Self.docs)) { Path { "docs"; DocsRoute.parser() } }

        // GET /faq
        Route(.case(Self.faq)) { Path { "faq" } }

        // GET /
        Route(.case(Self.home))

        // GET /keywords/:keyword?page=1
        Route(.case(Self.keywords(keyword:page:))) {
            Path { "keywords" }; Path { Parse(.string) }
            Query { Field("page", default: 1) { Int.parser() } }
        }

        // /:owner/:repository/...
        Route(.case(Self.package(owner:repository:route:))) {
            Path { Parse(.string) }
            Path { Parse(.string) }
            PackageRoute.router
        }

        // GET /package-collections
        Route(.case(Self.packageCollections)) { Path { "package-collections" } }

        // GET /privacy
        Route(.case(Self.privacy)) { Path { "privacy" } }

        // GET /try-in-a-playground?dependencies=foo/bar
        Route(.case(Self.tryInPlayground(dependencies:))) {
            Path { "try-in-a-playground"}
            Optionally {
                Query {
                    Field("dependencies")
                }
            }
        }
    }

    static func handler(req: Request, route: SiteRoute) async throws -> AsyncResponseEncodable {
        switch route {
            case let .api(.search(query: query, page: page)):
                return try await API.SearchController.get(req: req, query: query, page: page).get()

            case .api(.version):
                return API.Version(version: appVersion ?? "Unknown")

            case .addAPackage, .docs, .faq, .packageCollections, .privacy, .tryInPlayground:
                let filename = try router.print(route).path.joined(separator: "/") + ".md"
                return MarkdownPage(path: req.url.path, filename).document()

            case .home:
                return try await HomeIndex.Model.query(database: req.db).map {
                    HomeIndex.View(path: req.url.path, model: $0).document()
                }.get()

            case let .keywords(keyword: keyword, page: page):
                return try await KeywordController.show(req: req, keyword: keyword, page: page).get()

            case let .package(owner: owner, repository: repository, route: packageRoute):
                return try await PackageRoute.handler(req: req, owner: owner, repository: repository, route: packageRoute)
        }
    }
}


enum ApiRoute {
    case search(query: String, page: Int)
    case version

    static let router = OneOf {
        // GET /search?query="foo"&page=1
        Route(.case(Self.search)) {
            Path { "search" }
            Query {
                Field("query", default: "")
                Field("page", default: 1) { Int.parser() }
            }
        }

        // GET /version
        Route(.case(Self.version)) { Path { "version" } }
    }
}


enum DocsRoute: String, CaseIterable {
    case builds
}


enum PackageRoute {
    case show

    static let router = OneOf {
        Route(.case(Self.show))
    }

    static func handler(req: Request, owner: String, repository: String, route: PackageRoute) async throws -> AsyncResponseEncodable {
        switch route {
            case .show:
                return try await PackageController
                    .show(req: req, owner: owner, repository: repository)
        }
    }
}


// MARK: - URL printer helpers

extension SiteRoute {
    static func absoluteURL(for route: Self) -> String {
        router
            .baseURL(Current.siteURL())
            .url(for: route).absoluteString
    }

    static func absoluteURL(for route: Self, anchor: String) -> String {
        absoluteURL(for: route) + "#\(anchor)"
    }

    static func relativeURL(for route: Self) -> String {
        router.path(for: route)
    }

    static func relativeURL(for route: Self, anchor: String) -> String {
        relativeURL(for: route) + "#\(anchor)"
    }
}
