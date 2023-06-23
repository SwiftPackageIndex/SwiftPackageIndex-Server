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

import Vapor
import Foundation


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
                label = "Platform Compatibility"
            case .swiftVersions:
                label = "Swift Compatibility"
        }

        let (message, success) = Self.badgeMessage(significantBuilds: significantBuilds,
                                                   badgeType: badgeType)
        self.init(schemaVersion: 1,
                  label: label,
                  message: message,
                  isError: !success,
                  color: success ? "F05138" : "inactive",
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
        let pathToFile = Current.fileManager.workingDirectory()
            .appending("Public/images/logo-tiny.svg")

        return try? String(contentsOfFile: pathToFile)
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
        return Array(
            Set(
                platforms
                    .map { p -> Pair<Int, String> in
                        switch p {
                            case .iOS:
                                return .init(left: 0, right: "iOS")
                            case .macosSpm, .macosXcodebuild:
                                return .init(left: 1, right: "macOS")
                            case .linux:
                                return .init(left: 2, right: "Linux")
                            case .tvOS:
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
