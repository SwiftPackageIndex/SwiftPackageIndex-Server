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
        var isError: Bool
        var color: String
        var cacheSeconds: Int
        var logoSvg: String?
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

        let message = badgeMessage(badgeType: badgeType)
        return Badge(schemaVersion: 1,
                     label: label,
                     message: message ?? "unavailable",
                     isError: message == nil,
                     color: message == nil ? "inactive" : "F05138",
                     cacheSeconds: cacheSeconds,
                     logoSvg: Package.loadSVGLogo())
    }


    func badgeMessage(badgeType: BadgeType) -> String? {
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
    
    static private func loadSVGLogo() -> String? {
        let pathToFile = Current.fileManager.workingDirectory()
            .appending("Public/images/logo-tiny.svg")
        
        return try? String(contentsOfFile: pathToFile)
    }

}


func _badgeMessage(platforms: [Build.Platform]) -> String? {
    guard !platforms.isEmpty else { return nil }
    struct Value: Hashable {
        var index: Int
        var value: String
        init(_ index: Int, _ value: String) {
            self.index = index
            self.value = value
        }
    }
    return Array(
        Set(
            platforms
                .map { p -> Value in
                    switch p {
                        case .ios:
                            return .init(0, "iOS")
                        case .macosSpm, .macosXcodebuild, .macosSpmArm, .macosXcodebuildArm:
                            return .init(1, "macOS")
                        case .linux:
                            return .init(2, "Linux")
                        case .tvos:
                            return .init(3, "tvOS")
                        case .watchos:
                            return .init(4, "watchOS")
                    }
                }
        )
    )
    .sorted {
        $0.index < $1.index
    }
    .map { $0.value }
    .joined(separator: " | ")
}


func _badgeMessage(swiftVersions: [SwiftVersion]) -> String? {
    guard !swiftVersions.isEmpty else { return nil }
    return swiftVersions
        .map(\.displayName)
        .sorted { $0 > $1 }
        .joined(separator: " | ")
}
