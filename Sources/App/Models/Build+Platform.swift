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

extension Build {
    enum Platform: String, Codable, Equatable, CaseIterable {
        case ios
        case macosSpm           = "macos-spm"
        case macosXcodebuild    = "macos-xcodebuild"
        case tvos
        case watchos
        case linux

        var name: String {
            switch self {
                case .ios:
                    return "iOS"
                case .macosSpm:
                    return "macOS - SPM"
                case .macosXcodebuild:
                    return "macOS - xcodebuild"
                case .tvos:
                    return "tvOS"
                case .watchos:
                    return "watchOS"
                case .linux:
                    return "Linux"
            }
        }

        var displayName: String {
            switch self {
                case .ios:
                    return "iOS"
                case .macosSpm:
                    return "macOS (SPM)"
                case .macosXcodebuild:
                    return "macOS (Xcode)"
                case .tvos:
                    return "tvOS"
                case .watchos:
                    return "watchOS"
                case .linux:
                    return "Linux"
            }
        }

        /// Currently supported build platforms
        static var allActive: [Self] {
            [.ios, .macosSpm, .macosXcodebuild, .linux, .tvos, .watchos]
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
