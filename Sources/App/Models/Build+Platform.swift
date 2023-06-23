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

import SPIManifest


extension Build {
    enum Platform: String, Codable, Equatable, CaseIterable {
        case iOS                = "ios"
        case linux
        case macosSpm           = "macos-spm"
        case macosXcodebuild    = "macos-xcodebuild"
        case tvOS               = "tvos"
        case visionOS           = "visionos"
        case watchOS            = "watchos"

        var name: String {
            switch self {
                case .iOS:
                    return "iOS"
                case .macosSpm:
                    return "macOS - SPM"
                case .macosXcodebuild:
                    return "macOS - xcodebuild"
                case .tvOS:
                    return "tvOS"
                case .watchOS:
                    return "watchOS"
                case .visionOS:
                    return "visionOS"
                case .linux:
                    return "Linux"
            }
        }

        var displayName: String {
            switch self {
                case .iOS:
                    return "iOS"
                case .macosSpm:
                    return "macOS (SPM)"
                case .macosXcodebuild:
                    return "macOS (Xcode)"
                case .tvOS:
                    return "tvOS"
                case .watchOS:
                    return "watchOS"
                case .visionOS:
                    return "visionOS"
                case .linux:
                    return "Linux"
            }
        }

        /// Currently supported build platforms
        static var allActive: [Self] {
            let active: [Self] = [.iOS, .macosSpm, .macosXcodebuild, .linux, .tvOS, .visionOS, .watchOS]
            precondition(active.count == allCases.count, "mismatch in Build.Platform and active platform count")
            return active
        }


        /// This initialiser is unused. Its only purpose is to ensure that platform changes in the upstream package `SPIManifest.Platform`
        /// automatically trigger corresponding changes in `Build.Platform` to keep the two enums aligned.
        /// - Parameter spiManifestPlatform: SPIManifest platform
        private init(_ spiManifestPlatform: SPIManifest.Platform) {
            switch spiManifestPlatform {
                case .iOS:
                    self = .iOS
                case .linux:
                    self = .linux
                case .macosSpm:
                    self = .macosSpm
                case .macosXcodebuild:
                    self = .macosXcodebuild
                case .tvOS:
                    self = .tvOS
                case .visionOS:
                    self = .visionOS
                case .watchOS:
                    self = .watchOS
            }
        }
    }
}


extension Build.Platform: Comparable {
    static func < (lhs: Build.Platform, rhs: Build.Platform) -> Bool {
        switch (allActive.firstIndex(of: lhs), allActive.firstIndex(of: rhs)) {
            case let (.some(idx1), .some(idx2)):
                return idx1 < idx2
            default:
                return lhs.rawValue < rhs.rawValue
        }
    }
}


extension Build.Platform: LosslessStringConvertible {
    init?(_ description: String) {
        self.init(rawValue: description)
    }

    var description: String {
        rawValue
    }
}
