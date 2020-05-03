import Foundation


struct Manifest: Codable {
    struct Platform: Codable {
        enum Name: String, Codable {
            case macos
            case ios
            case tvos
            case watchos
        }
        var platformName: Name
        var version: String
    }
    var name: String
    var swiftLanguageVersions: [String]?
    var platforms: [Platform]?
}


extension Manifest.Platform: CustomStringConvertible {
    var description: String { "\(platformName)_\(version)" }
}
