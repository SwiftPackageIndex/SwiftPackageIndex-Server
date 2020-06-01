import Plot
import Vapor


enum Resource {
    enum Parameter<T> {
        case name(String)
        case value(T)
    }
    case admin
    case about
    case home
    case packages
    case package(_ parameter: Parameter<Package.Id>)
    case privacy

    var relativePath: String {
        switch self {
            case .admin:
                return "admin"
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
            case let .package(.name(name)):
                return [.init(stringLiteral: relativePath), .init(stringLiteral: ":\(name)")]
            case .package(.value(_)):
                fatalError("pathComponents must not be called with a value parameter")
            default:
                return [.init(stringLiteral: relativePath)]
        }
    }
}


extension Array where Element == PathComponent {
    static func path(for resource: Resource) -> [PathComponent] {
        resource.pathComponents
    }
}


extension PathComponent {
    static func path(for resource: Resource) -> [PathComponent] {
        resource.pathComponents
    }
}


extension Node where Context: HTMLLinkableContext {
    static func href(_ resource: Resource) -> Node {
        .attribute(named: "href", value: resource.absolutePath)
    }
}
