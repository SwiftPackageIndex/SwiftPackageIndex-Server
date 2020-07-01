import Foundation


struct Platform: Codable, Equatable {
    enum Name: String, Codable, Equatable, CaseIterable {
        case ios
        case macos
        case watchos
        case tvos
    }
    var name: Name
    var version: String
    
    static func ios(_ version: String) -> Self { .init(name: .ios, version: version) }
    static func macos(_ version: String) -> Self { .init(name: .macos, version: version) }
    static func watchos(_ version: String) -> Self { .init(name: .watchos, version: version) }
    static func tvos(_ version: String) -> Self { .init(name: .tvos, version: version) }
}


extension Platform {
    init?(from dto: Manifest.Platform) {
        guard let name = Platform.Name(rawValue: dto.platformName.rawValue) else { return nil }
        self.name = name
        self.version = dto.version
    }
}


extension Platform: CustomStringConvertible {
    var description: String {
        switch name {
            case .ios:
                return "iOS \(version)"
            case .macos:
                return "macOS \(version)"
            case .watchos:
                return "watchOS \(version)"
            case .tvos:
                return "tvOS \(version)"
        }
    }
}
