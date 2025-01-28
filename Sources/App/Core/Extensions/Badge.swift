// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Foundation

import Dependencies
import Vapor


struct Badge: Content, Equatable {
    var schemaVersion: Int
    var label: String
    var message: String
    var isError: Bool
    var color: String
    var cacheSeconds: Int
    var logoSvg: String?

    private init(schemaVersion: Int, label: String, message: String, isError: Bool, color: String, cacheSeconds: Int, logoSvg: String? = nil) {
        self.schemaVersion = schemaVersion
        self.label = label
        self.message = message
        self.isError = isError
        self.color = color
        self.cacheSeconds = cacheSeconds
        self.logoSvg = logoSvg
    }

    init(significantBuilds: SignificantBuilds, badgeType: BadgeType) {
        let cacheSeconds = 6*3600

        let label: String
        switch badgeType {
            case .platforms:
                label = "Platforms"
            case .swiftVersions:
                label = "Swift"
        }

        let (message, success) = Self.badgeMessage(significantBuilds: significantBuilds,
                                                   badgeType: badgeType)
        self.init(schemaVersion: 1,
                  label: label,
                  message: message,
                  isError: !success,
                  color: success ? "blue" : "inactive",
                  cacheSeconds: cacheSeconds,
                  logoSvg: Self.loadSVGLogo())
    }
}


enum BadgeType: String, Codable {
    case platforms
    case swiftVersions = "swift-versions"
}


extension Badge {

    static private func loadSVGLogo() -> String? {
        @Dependency(\.fileManager) var fileManager
        let pathToFile = fileManager.workingDirectory().appending("Public/images/logo-tiny.svg")

        return try? String(contentsOfFile: pathToFile, encoding: .utf8)
    }

    static func badgeMessage(significantBuilds: SignificantBuilds, badgeType: BadgeType) -> (message: String, success: Bool) {
        switch badgeType {
            case .platforms:
                switch significantBuilds.platformCompatibility() {
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
                switch significantBuilds.swiftVersionCompatibility() {
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

    static func badgeMessage(platforms: [Build.Platform]) -> String? {
        guard !platforms.isEmpty else { return nil }
        // The order of this array defines the platform order on the build badges. Keep this aligned
        // with the order in Build.Platform.
        return Array(
            Set(
                platforms
                    .map { p -> Pair<Int, String> in
                        switch p {
                            case .iOS:
                                return .init(left: 0, right: "iOS")
                            case .macosSpm, .macosXcodebuild:
                                return .init(left: 1, right: "macOS")
                            case .visionOS:
                                return .init(left: 2, right: "visionOS")
                            case .tvOS:
                                return .init(left: 3, right: "tvOS")
                            case .watchOS:
                                return .init(left: 4, right: "watchOS")
                            case .linux:
                                return .init(left: 5, right: "Linux")
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
            .sorted { $0 > $1 }
            .map(\.displayName)
            .joined(separator: " | ")
    }

}
