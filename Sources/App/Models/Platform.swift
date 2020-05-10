import Foundation


struct Platform: Codable, Equatable {
    enum Name: String, Codable, Equatable, CaseIterable {
        case macos
        case ios
        case tvos
        case watchos
    }
    var name: Name
    var version: String

    static func macos(_ version: String) -> Self { .init(name: .macos, version: version) }
    static func ios(_ version: String) -> Self { .init(name: .ios, version: version) }
    static func tvos(_ version: String) -> Self { .init(name: .tvos, version: version) }
    static func watchos(_ version: String) -> Self { .init(name: .watchos, version: version) }
}


extension Platform {
    init?(from dto: Manifest.Platform) {
        guard let name = Platform.Name(rawValue: dto.platformName.rawValue) else { return nil }
        self.name = name
        self.version = dto.version
    }
}
