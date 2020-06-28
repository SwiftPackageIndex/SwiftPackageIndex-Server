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


enum Api: Resourceable {
    case packages(_ owner: Parameter<String>, _ repository: Parameter<String>, PackagesPathComponents)
    case search
    case version
    case versions(_ id: Parameter<UUID>, VersionsPathComponents)
    
    var path: String {
        switch self {
            case let .packages(.value(owner), .value(repo), next):
                return "packages/\(owner)/\(repo)/\(next.path)"
            case .packages:
                fatalError("path must not be called with a name parameter")
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
            case let .packages(.key, .key, remainder):
                return ["packages", ":owner", ":repository"] + remainder.pathComponents
            case .packages:
                fatalError("pathComponents must not be called with a value parameter")
            case .search, .version:
                return [.init(stringLiteral: path)]
            case let .versions(.key, remainder):
                return ["versions", ":id"] + remainder.pathComponents
            case .versions(.value, _):
                fatalError("pathComponents must not be called with a value parameter")
        }
    }
    
    enum PackagesPathComponents: String, Resourceable {
        case triggerBuilds = "trigger-builds"
    }
    
    enum VersionsPathComponents: String, Resourceable {
        case builds
        case triggerBuild = "trigger-build"
    }
    
}


enum SiteURL: Resourceable {
    
    case admin
    case api(Api)
    case faq
    case addAPackage
    case home
    case images(String)
    case packages
    case package(_ owner: Parameter<String>, _ repository: Parameter<String>)
    case privacy
    case rssPackages
    case rssReleases
    case siteMap
    
    var path: String {
        switch self {
            case .admin:
                return "admin"
                
            case let .api(next):
                return "api/\(next.path)"
                
            case .faq:
                return "faq"
                
            case .addAPackage:
                return "add-a-package"
                
            case .home:
                return ""
                
            case let .images(name):
                return "images/\(name)"
                
            case let .package(.value(owner), .value(repo)):
                let owner = owner.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? owner
                let repo = repo.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? repo
                return "\(owner)/\(repo)"
                
            case .package:
                fatalError("invalid path: \(self)")
                
            case .packages:
                return "packages"
                
            case .privacy:
                return "privacy"
                
            case .rssPackages:
                return "packages.rss"
                
            case .rssReleases:
                return "releases.rss"
                
            case .siteMap:
                return "sitemap.xml"
        }
    }
    
    var pathComponents: [PathComponent] {
        switch self {
            case .admin, .faq, .addAPackage, .home, .packages, .privacy, .rssPackages, .rssReleases, .siteMap:
                return [.init(stringLiteral: path)]
                
            case let .api(res):
                return ["api"] + res.pathComponents
                
            case .package(.key, .key):
                return [":owner", ":repository"]
                
            case .package:
                fatalError("pathComponents must not be called with a value parameter")
                
            case .images:
                fatalError("invalid resource path for routing - only use in static HTML (DSL)")
        }
    }
    
    static func relativeURL(for path: String) -> String {
        guard path.hasPrefix("/") else { return "/" + path }
        return path
    }
    
    static func absoluteURL(for path: String) -> String {
        Current.siteURL() + relativeURL(for: path)
    }
    
    static var apiBaseURL: String { absoluteURL(for: "api") }
    
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
        "\(Current.siteURL())/\(path)" + (anchor.map { "#\($0)" } ?? "")
    }
    
    func absoluteURL(parameters: [String: String]) -> String {
        "\(Current.siteURL())/\(path)\(parameters.queryString())"
    }
    
    func relativeURL(anchor: String? = nil) -> String {
        "/" + path + (anchor.map { "#\($0)" } ?? "")
    }
}


extension Resourceable where Self: RawRepresentable, RawValue == String {
    var path: String { rawValue }
    var pathComponents: [PathComponent] { [.init(stringLiteral: path)] }
}


enum Parameter<T> {
    case key
    case value(T)
}
