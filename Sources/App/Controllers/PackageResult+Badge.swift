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


extension PackageController.PackageResult {

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
    static func swiftVersionCompatibility(_ builds: SignificantBuilds) -> CompatibilityResult<SwiftVersion> {
        if builds.allSatisfy({ $0.status == .triggered }) { return .pending }
        
        let builds = builds
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

    struct SignificantBuilds {
        var builds: [Build]

        init(versions: [Version]) {
            self.builds = [Version.Kind.release, .preRelease, .defaultBranch]
                .compactMap(versions.latest(for:))
                .reduce(into: []) {
                    $0.append(contentsOf: $1.$builds.value ?? [])
                }
        }

        func allSatisfy(_ predicate: (Build) throws -> Bool) rethrows -> Bool {
            try builds.allSatisfy(predicate)
        }

        func filter(_ isIncluded: (Build) throws -> Bool) rethrows -> [Build] {
            try builds.filter(isIncluded)
        }
    }

    /// Returns platform compatibility across a package's significant versions.
    /// - Returns: A `CompatibilityResult` of `Platform`
    static func platformCompatibility(_ builds: SignificantBuilds) -> CompatibilityResult<Build.Platform> {
        if builds.allSatisfy({ $0.status == .triggered }) { return .pending }

        let builds = builds
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

        let significantBuilds = SignificantBuilds(versions: versions)
        let (message, success) = Self.badgeMessage(significantBuilds: significantBuilds,
                                                   badgeType: badgeType)
        return Badge(schemaVersion: 1,
                     label: label,
                     message: message,
                     isError: !success,
                     color: success ? "F05138" : "inactive",
                     cacheSeconds: cacheSeconds,
                     logoSvg: Self.loadSVGLogo())
    }

    static func badgeMessage(significantBuilds: SignificantBuilds, badgeType: BadgeType) -> (message: String, success: Bool) {
        switch badgeType {
            case .platforms:
                switch platformCompatibility(significantBuilds) {
                    case .available(let platforms):
                        if let message = badgeMessage(platforms: platforms) {
                            return (message, true)
                        } else {
                            return ("unavailable", false)
                        }
                    case .pending:
                        return ("pending", false)
                }
            case .swiftVersions:
                switch swiftVersionCompatibility(significantBuilds) {
                    case .available(let versions):
                        if let message = badgeMessage(swiftVersions: versions) {
                            return (message, true)
                        } else {
                            return ("unavailable", false)
                        }
                    case .pending:
                        return ("pending", false)
                }
        }
    }

    static private func loadSVGLogo() -> String? {
        let pathToFile = Current.fileManager.workingDirectory()
            .appending("Public/images/logo-tiny.svg")

        return try? String(contentsOfFile: pathToFile)
    }


    static func badgeMessage(platforms: [Build.Platform]) -> String? {
        guard !platforms.isEmpty else { return nil }
        return Array(
            Set(
                platforms
                    .map { p -> Pair<Int, String> in
                        switch p {
                            case .ios:
                                return .init(left: 0, right: "iOS")
                            case .macosSpm, .macosXcodebuild, .macosSpmArm, .macosXcodebuildArm:
                                return .init(left: 1, right: "macOS")
                            case .linux:
                                return .init(left: 2, right: "Linux")
                            case .tvos:
                                return .init(left: 3, right: "tvOS")
                            case .watchos:
                                return .init(left: 4, right: "watchOS")
                        }
                    }
                )
            )
            .sorted {
                $0.left < $1.left
            }
            .map { $0.right }
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
