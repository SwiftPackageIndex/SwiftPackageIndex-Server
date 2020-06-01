import Plot
import Vapor


enum Resource {
    case admin
    case about
    case home
    case packages(_ id: Package.Id)
    case privacy

    var relativePath: String {
        switch self {
            case .admin:
                return "admin"
            case .about:
                return "about"
            case .home:
                return ""
            case let .packages(id):
                return "packages/\(id)"
            case .privacy:
                return "privacy"
        }
    }

    var absolutePath: String { "/" + relativePath }
}


extension PathComponent {
    static func url(for resource: Resource, relative: Bool = true) -> PathComponent {
        .init(stringLiteral: relative ? resource.relativePath : resource.absolutePath)
    }
}


extension Node where Context: HTMLLinkableContext {
    static func href(_ resource: Resource) -> Node {
        .attribute(named: "href", value: resource.absolutePath)
    }
}
