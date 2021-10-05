// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Vapor


extension Package {

    enum CompatibilityResult<Value: Equatable>: Equatable {
        case available([Value])
        case pending
        
        var values: [Value]? {
            switch self {
                case .available(let values):
                    return values
                case .pending:
                    return nil
            }
        }
    }


    /// Returns swift versions compatibility across a package's significant versions.
    /// - Returns: A `CompatibilityResult` of `SwiftVersion`
    func swiftVersionCompatibility() -> CompatibilityResult<SwiftVersion> {
        let allBuilds = allSignificantBuilds()
        if allBuilds.allSatisfy({ $0.status == .triggered }) { return .pending }
        
        let builds = allBuilds
            .filter { $0.status == .ok }
        let compatibility = SwiftVersion.allActive.map { swiftVersion -> (SwiftVersion, Bool) in
            for build in builds {
                if build.swiftVersion.isCompatible(with: swiftVersion) {
                    return (swiftVersion, true)
                }
            }
            return (swiftVersion, false)
        }
        return .available(
            compatibility
                .filter { $0.1 }
                .map { $0.0 }
        )
    }


    /// Returns platform compatibility across a package's significant versions.
    /// - Returns: A `CompatibilityResult` of `Platform`
    func platformCompatibility() -> CompatibilityResult<Build.Platform> {
        let allBuilds = allSignificantBuilds()
        if allBuilds.allSatisfy({ $0.status == .triggered }) { return .pending }
        
        let builds = allBuilds
            .filter { $0.status == .ok }
        let compatibility = Build.Platform.allActive.map { platform -> (Build.Platform, Bool) in
            for build in builds {
                if build.platform == platform {
                    return (platform, true)
                }
            }
            return (platform, false)
        }
        return .available(
            compatibility
                .filter { $0.1 }
                .map { $0.0 }
        )
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

        let (message, success) = badgeMessage(badgeType: badgeType)
        return Badge(schemaVersion: 1,
                     label: label,
                     message: message,
                     isError: !success,
                     color: success ? "F05138" : "inactive",
                     cacheSeconds: cacheSeconds,
                     logoSvg: Package.loadSVGLogo())
    }


    func badgeMessage(badgeType: BadgeType) -> (message: String, success: Bool) {
        switch badgeType {
            case .platforms:
                switch platformCompatibility() {
                    case .available(let platforms):
                        if let message = Self.badgeMessage(platforms: platforms) {
                            return (message, true)
                        } else {
                            return ("unavailable", false)
                        }
                    case .pending:
                        return ("pending", false)
                }
            case .swiftVersions:
                switch swiftVersionCompatibility() {
                    case .available(let versions):
                        if let message = Self.badgeMessage(swiftVersions: versions) {
                            return (message, true)
                        } else {
                            return ("unavailable", false)
                        }
                    case .pending:
                        return ("pending", false)
                }
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


    static func badgeMessage(platforms: [Build.Platform]) -> String? {
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


    static func badgeMessage(swiftVersions: [SwiftVersion]) -> String? {
        guard !swiftVersions.isEmpty else { return nil }
        return swiftVersions
            .map(\.displayName)
            .sorted { $0 > $1 }
            .joined(separator: " | ")
    }

}
