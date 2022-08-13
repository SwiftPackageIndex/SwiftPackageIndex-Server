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
    case docs(DocsRoute)
    case home
    case package(owner: String, repository: String, route: PackageRoute = .show)
    case staticPath(StaticPathRoute)

    enum StaticPathRoute: String, CaseIterable {
        case addAPackage = "add-a-package"
        case faq
        case packageCollections = "package-collections"
        case privacy
        case tryInPlayground = "try-package"
    }

    static let router = OneOf {
        Route(.case(Self.home))

        Route(.case(Self.docs)) { Path { "docs"; DocsRoute.parser() } }

        Route(.case(Self.package(owner:repository:route:))) {
            Path { Parse(.string) }
            Path { Parse(.string) }
            PackageRoute.router
        }

        Route(.case(Self.staticPath)) { Path { StaticPathRoute.parser() } }
    }

    static func handler(req: Request, route: SiteRoute) async throws -> AsyncResponseEncodable {
        switch route {
            case .docs(.builds), .staticPath:
                let filename = try router.print(route).path.joined(separator: "/") + ".md"
                return MarkdownPage(path: req.url.path, filename).document()

            case .home:
                return try await HomeIndex.Model.query(database: req.db).map {
                    HomeIndex.View(path: req.url.path, model: $0).document()
                }.get()

            case let .package(owner: owner, repository: repository, route: packageRoute):
                return try await PackageRoute.handler(req: req, owner: owner, repository: repository, route: packageRoute)
        }
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


extension SiteRoute {
    static func absoluteURL(for route: Self) -> String {
        Current.siteURL() + router.path(for: route)
    }

    static func absoluteURL(for route: Self, anchor: String) -> String {
        absoluteURL(for: route) + "#\(anchor)"
    }

    static func relativeURL(for route: Self) -> String {
        router.path(for: route)
    }
}
