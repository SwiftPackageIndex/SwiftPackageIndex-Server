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
import Plot
import Vapor


// MARK: - Resource declaration


// The following are all the routes we support and reference from various places, some of them
// static routes (images), others dynamic ones for use in controller definitions.
//
// Introduce nesting by declaring a new type conforming to Resourceable and embed it in the
// parent resource.
//
// Enums based on String are automatically Resourceable via RawRepresentable.


enum Api: Resourceable, Sendable {
    case builds(_ id: Parameter<UUID>, BuildsPathComponents)
    case dependencies
    case packages(_ owner: Parameter<String>, _ repository: Parameter<String>, PackagesPathComponents)
    case packageCollections
    case search
    case version
    case versions(_ id: Parameter<UUID>, VersionsPathComponents)

    var path: String {
        switch self {
            case let .builds(.value(id), next):
                return "builds/\(id.uuidString)/\(next.path)"
            case .builds(.key, _):
                fatalError("path must not be called with a name parameter")
            case .dependencies:
                return "dependencies"
            case let .packages(.value(owner), .value(repo), next):
                return "packages/\(owner)/\(repo)/\(next.path)"
            case .packages:
                fatalError("path must not be called with a name parameter")
            case .packageCollections:
                return "package-collections"
            case .version:
                return "version"
            case let .versions(.value(id), next):
                return "versions/\(id.uuidString)/\(next.path)"
            case .versions(.key, _):
                fatalError("path must not be called with a name parameter")
            case .search:
                return "search"
        }
    }

    var pathComponents: [PathComponent] {
        switch self {
            case let .builds(.key, remainder):
                return ["builds", ":id"] + remainder.pathComponents
            case .builds(.value, _):
                fatalError("pathComponents must not be called with a value parameter")
            case let .packages(.key, .key, remainder):
                return ["packages", ":owner", ":repository"] + remainder.pathComponents
            case .packages:
                fatalError("pathComponents must not be called with a value parameter")
            case .packageCollections:
                return ["package-collections"]
            case .dependencies, .search, .version:
                return [.init(stringLiteral: path)]
            case let .versions(.key, remainder):
                return ["versions", ":id"] + remainder.pathComponents
            case .versions(.value, _):
                fatalError("pathComponents must not be called with a value parameter")
        }
    }

    enum BuildsPathComponents: String, Resourceable {
        case docReport = "doc-report"
    }

    enum PackagesPathComponents: String, Resourceable {
        case badge
    }

    enum VersionsPathComponents: String, Resourceable {
        case buildReport = "build-report"
    }

}


enum Docs: String, Resourceable {
    case builds
}


enum SiteURL: Resourceable, Sendable {

    case addAPackage
    case api(Api)
    case author(_ owner: Parameter<String>)
    case blog
    case blogFeed
    case blogPost(_ slug: Parameter<String>)
    case buildMonitor
    case builds(_ id: Parameter<UUID>)
    case collections(_ key: Parameter<String>)
    case docs(Docs)
    case faq
    case home
    case images(String)
    case javascripts(String)
    case keywords(_ keyword: Parameter<String>)
    case package(_ owner: Parameter<String>, _ repository: Parameter<String>, PackagePathComponents?)
    case packageCollectionKeyword(_ keyword: Parameter<String>)
    case packageCollectionAuthor(_ owner: Parameter<String>)
    case packageCollectionCustom(_ key: Parameter<String>)
    case packageCollections
    case privacy
    case readyForSwift6
    case rssPackages
    case rssReleases
    case search
    case siteMapIndex
    case siteMapStaticPages
    case stylesheets(String)
    case supporters
    case tryInPlayground
    case healthCheck
    case validateSPIManifest

    var path: String {
        switch self {
            case .addAPackage:
                return "add-a-package"

            case let .api(next):
                return "api/\(next.path)"

            case let .author(.value(owner)):
                return owner

            case .author:
                fatalError("invalid path: \(self)")

            case .blog:
                return "blog"

            case .blogFeed:
                return "blog/feed.xml"

            case let .blogPost(.value(slug)):
                return "blog/\(slug)"

            case .blogPost:
                fatalError("invalid path: \(self)")

            case let .builds(.value(id)):
                return "builds/\(id.uuidString)"

            case .builds(.key):
                fatalError("invalid path: \(self)")

            case .buildMonitor:
                return "build-monitor"

            case let .collections(.value(key)):
                return "collections/\(key.urlPathEncoded)"

            case .collections(.key):
                fatalError("invalid path: \(self)")

            case let .docs(next):
                return "docs/\(next.path)"

            case .faq:
                return "faq"

            case .home:
                return ""

            case let .images(name):
                return "images/\(name)"

            case let .javascripts(name):
                return "/\(name).js"

            case let .keywords(.value(keyword)):
                return "keywords/\(keyword)"

            case .keywords:
                fatalError("invalid path: \(self)")

            case let .package(.value(owner), .value(repo), .none):
                let owner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
                let repo = repo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repo
                return "\(owner)/\(repo)"

            case let .package(owner, repo, .some(next)):
                return "\(Self.package(owner, repo, .none).path)/\(next.path)"

            case .package:
                fatalError("invalid path: \(self)")

            case let .packageCollectionKeyword(.value(keyword)):
                return "keywords/\(keyword)/collection.json"

            case .packageCollectionKeyword(.key):
                fatalError("invalid path: \(self)")

            case let .packageCollectionAuthor(.value(owner)):
                return "\(owner)/collection.json"

            case .packageCollectionAuthor(.key):
                fatalError("invalid path: \(self)")

            case let .packageCollectionCustom(.value(key)):
                return "collections/\(key.urlPathEncoded)/collection.json"

            case .packageCollectionCustom(.key):
                fatalError("invalid path: \(self)")

            case .packageCollections:
                return "package-collections"

            case .privacy:
                return "privacy"

            case .readyForSwift6:
                return "ready-for-swift-6"

            case .rssPackages:
                return "packages.rss"

            case .rssReleases:
                return "releases.rss"

            case .search:
                return "search"

            case .siteMapIndex:
                return "sitemap.xml"

            case .siteMapStaticPages:
                return "sitemap-static-pages.xml"

            case .supporters:
                return "supporters"

            case let .stylesheets(name):
                return "/\(name).css"

            case .tryInPlayground:
                return "try-in-a-playground"

            case .healthCheck:
                return "health-check"

            case .validateSPIManifest:
                return "validate-spi-manifest"
        }
    }

    var pathComponents: [PathComponent] {
        switch self {
            case .addAPackage,
                    .blog,
                    .buildMonitor,
                    .faq,
                    .home,
                    .packageCollections,
                    .privacy,
                    .readyForSwift6,
                    .rssPackages,
                    .rssReleases,
                    .search,
                    .siteMapIndex,
                    .siteMapStaticPages,
                    .supporters,
                    .tryInPlayground,
                    .healthCheck,
                    .validateSPIManifest:
                return [.init(stringLiteral: path)]

            case let .api(next):
                return ["api"] + next.pathComponents

            case .author:
                return [":owner"]

            case .blogFeed:
                return ["blog", "feed.xml"]

            case .blogPost:
                return ["blog", ":slug"]

            case .builds(.key):
                return ["builds", ":id"]

            case .builds(.value):
                fatalError("pathComponents must not be called with a value parameter")

            case .collections(.key):
                return ["collections", ":key"]

            case .collections(.value):
                fatalError("pathComponents must not be called with a value parameter")

            case let .docs(next):
                return ["docs"] + next.pathComponents

            case .keywords:
                return ["keywords", ":keyword"]

            case .package(.key, .key, .none):
                return [":owner", ":repository"]

            case let .package(k1, k2, .some(next)):
                return Self.package(k1, k2, .none).pathComponents + next.pathComponents

            case .package:
                fatalError("pathComponents must not be called with a value parameter")

            case .packageCollectionKeyword(.key):
                return ["keywords", ":keyword", "collection.json"]

            case .packageCollectionKeyword(.value):
                fatalError("pathComponents must not be called with a value parameter")

            case .packageCollectionAuthor(.key):
                return [":owner", "collection.json"]

            case .packageCollectionAuthor(.value):
                fatalError("pathComponents must not be called with a value parameter")

            case .packageCollectionCustom(.key):
                return ["collections", ":key", "collection.json"]

            case .packageCollectionCustom(.value):
                fatalError("pathComponents must not be called with a value parameter")

            case .images, .javascripts, .stylesheets:
                fatalError("invalid resource path for routing - only use in static HTML (DSL)")
        }
    }

    static let _absoluteURL: @Sendable (String) -> String = { path in
        @Dependency(\.environment) var environment
        return environment.siteURL() + relativeURL(path)
    }

    static let _relativeURL: @Sendable (String) -> String = { path in
        guard path.hasPrefix("/") else { return "/" + path }
        return path
    }

#if DEBUG
    // make `var` for debug so we can dependency inject
    nonisolated(unsafe) static var absoluteURL = _absoluteURL
    nonisolated(unsafe) static var relativeURL = _relativeURL
#else
    static let absoluteURL = _absoluteURL
    static let relativeURL = _relativeURL

#endif
    static var apiBaseURL: String { absoluteURL("api") }

    enum PackagePathComponents: String, Resourceable {
        case readme
        case releases
        case builds
        case documentation
        case maintainerInfo = "information-for-package-maintainers"
        case siteMap = "sitemap.xml"
    }

}


// MARK: - Types for use in resource declaration


protocol Resourceable {
    func absoluteURL(anchor: String?) -> String
    func relativeURL(anchor: String?) -> String
    var path: String { get }
    var pathComponents: [PathComponent] { get }
}


extension Resourceable {
    func absoluteURL(anchor: String? = nil) -> String {
        "\(SiteURL.absoluteURL(path))" + (anchor.map { "#\($0)" } ?? "")
    }

    func absoluteURL(parameters: [QueryParameter], encodeParameters: Bool = true) -> String {
        "\(SiteURL.absoluteURL(path))\(parameters.queryString(encoded: encodeParameters))"
    }

    func relativeURL(anchor: String? = nil) -> String {
        "\(SiteURL.relativeURL(path))" + (anchor.map { "#\($0)" } ?? "")
    }

    func relativeURL(parameters: [QueryParameter]) -> String {
        "\(SiteURL.relativeURL(path))\(parameters.queryString())"
    }
}


extension Resourceable where Self: RawRepresentable, RawValue == String {
    var path: String { rawValue }
    var pathComponents: [PathComponent] { [.init(stringLiteral: path)] }
}


enum Parameter<T: Sendable>: Sendable {
    case key
    case value(T)
}

struct QueryParameter {
    var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    init(key: String, value: Int) {
        self.init(key: key, value: "\(value)")
    }

    var encodedForQueryString: String {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return "\(encodedKey)=\(encodedValue)"
    }

    var unencodedQueryString: String {
        return "\(key)=\(value)"
    }
}


extension SiteURL {
    static func relativeURL(owner: String,
                            repository: String,
                            documentation: DocumentationTarget,
                            fragment: DocRoute.Fragment,
                            path: String = "") -> String {
        switch (documentation, fragment) {
            case (.external(let url), _):
                return path.isEmpty
                ? url
                : url + "/" + path

            case let (.internal(reference, archive), .documentation):
                // Point documentation fragment URLs at the archive unless there's a specific path given.
                return path.isEmpty
                ? "/\(owner)/\(repository)/\(reference.pathEncoded)/\(fragment)/\(archive.lowercased())"
                : "/\(owner)/\(repository)/\(reference.pathEncoded)/\(fragment)/\(path)"

            case let (.internal(reference, _), _):
                // All other fragments (for instance `tutorials`) default to just the fragment plus optionally the path.
                return path.isEmpty
                ? "/\(owner)/\(repository)/\(reference.pathEncoded)/\(fragment)"
                : "/\(owner)/\(repository)/\(reference.pathEncoded)/\(fragment)/\(path)"
        }
    }
}
