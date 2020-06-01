import Plot
import Vapor


protocol Resourceable {
    var absolutePath: String { get }
    var relativePath: String { get }
    var pathComponents: [PathComponent] { get }
}


extension Resourceable where Self: RawRepresentable, RawValue == String {
    var absolutePath: String { "/" + relativePath }
    var relativePath: String { rawValue }
    var pathComponents: [PathComponent] { [.init(stringLiteral: relativePath)] }
}


enum Parameter<T> {
    case name(String)
    case value(T)
}


enum Api: String, Resourceable {
    case version
    case search
}


enum Root: Resourceable {

    case admin
    case api(Api)
    case about
    case home
    case packages
    case package(_ parameter: Parameter<Package.Id>)
    case privacy

    var relativePath: String {
        switch self {
            case .admin:
                return "admin"
            case .api:
                return "api"
            case .about:
                return "about"
            case .home:
                return ""
            case .packages, .package(.name):
                return "packages"
            case let .package(.value(value)):
                return "packages/\(value.uuidString)"
            case .privacy:
                return "privacy"
        }
    }

    var absolutePath: String { "/" + relativePath }

    var pathComponents: [PathComponent] {
        switch self {
            case let .api(res):
                return ["api"] + res.pathComponents
            case let .package(.name(name)):
                return [.init(stringLiteral: relativePath), .init(stringLiteral: ":\(name)")]
            case .package(.value(_)):
                fatalError("pathComponents must not be called with a value parameter")
            case .admin, .about, .home, .packages, .privacy:
                return [.init(stringLiteral: relativePath)]
        }
    }
}


extension Array where Element == PathComponent {
    static func path(for resource: Resourceable) -> [PathComponent] {
        resource.pathComponents
    }
}


extension PathComponent {
    static func path(for resource: Resourceable) -> [PathComponent] {
        resource.pathComponents
    }
}
