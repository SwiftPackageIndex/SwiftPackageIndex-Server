import Vapor


extension Package {

    /// Returns a list of compatible swift versions across a package's significant versions.
    /// - Returns: Array of compatible `SwiftVersion`s
    func swiftVersionCompatibility() -> [SwiftVersion] {
        let builds = allSignificantBuilds()
            .filter { $0.status == .ok }
        let compatibility = SwiftVersion.allActive.map { swiftVersion -> (SwiftVersion, Bool) in
            for build in builds {
                if build.swiftVersion.isCompatible(with: swiftVersion) {
                    return (swiftVersion, true)
                }
            }
            return (swiftVersion, false)
        }
        return compatibility
            .filter { $0.1 }
            .map { $0.0 }
    }


    /// Returns a list of compatible platforms across a package's significant versions.
    /// - Returns: Array of compatible `Platform`s
    func platformCompatibility() -> [Build.Platform] {
        let builds = allSignificantBuilds()
            .filter { $0.status == .ok }
        let compatibility = Build.Platform.allActive.map { platform -> (Build.Platform, Bool) in
            for build in builds {
                if build.platform == platform {
                    return (platform, true)
                }
            }
            return (platform, false)
        }
        return compatibility
            .filter { $0.1 }
            .map { $0.0 }
    }


    enum BadgeType: String {
        case platforms
        case swiftVersions = "swift-versions"
    }


    struct Badge: Content, Equatable {
        var schemaVersion: Int
        var label: String
        var message: String
        var color: String
        var cacheSeconds: Int
    }


    func badge(badgeType: BadgeType) -> Badge {
        let cacheSeconds = 6*3600

        let label: String
        switch badgeType {
            case .platforms:
                label = "Platform Compatibility"
            case .swiftVersions:
                label = "Swift Compatibility"
        }

        return Badge(schemaVersion: 1,
                     label: label,
                     message: badgeMessage(badgeType: badgeType),
                     color: "blue",
                     cacheSeconds: cacheSeconds)
    }


    func badgeMessage(badgeType: BadgeType) -> String {
        switch badgeType {
            case .platforms:
                return _badgeMessage(platforms: platformCompatibility())
            case .swiftVersions:
                return _badgeMessage(swiftVersions: swiftVersionCompatibility())
        }
    }


    /// Returns all builds for a packages significant versions
    /// - Returns: Array of `Build`s
    func allSignificantBuilds() -> [Build] {
        let versions = [Version.Kind.release, .preRelease, .defaultBranch]
            .compactMap(latestVersion(for:))
        return versions.reduce(into: []) {
            $0.append(contentsOf: $1.$builds.value ?? [])
        }
    }

}


private func _badgeMessage(platforms: [Build.Platform]) -> String {
    platforms.map {
        switch $0 {
            case .ios:
                return "iOS"
            case .macosSpm, .macosXcodebuild, .macosSpmArm, .macosXcodebuildArm:
                return "macOS"
            case .tvos:
                return "tvOS"
            case .watchos:
                return "watchOS"
            case .linux:
                return "Linux"
        }
    }
    .joined(separator: " | ")
}


private func _badgeMessage(swiftVersions: [SwiftVersion]) -> String {
    swiftVersions.map(\.displayName)
        .reversed()
        .joined(separator: " | ")
}
