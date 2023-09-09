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


struct Platform: Codable, Equatable {
    enum Name: String, Codable, Equatable, CaseIterable {
        // Keep aligned with https://github.com/apple/swift-package-manager/blob/main/Sources/PackageDescription/SupportedPlatforms.swift
        case android
        case custom
        case driverkit
        case ios
        case linux
        case maccatalyst
        case macos
        case openbsd
        case tvos
        case visionos
        case wasi
        case watchos
        case windows
    }
    var name: Name
    var version: String

    static func ios(_ version: String) -> Self { .init(name: .ios, version: version) }
    static func macos(_ version: String) -> Self { .init(name: .macos, version: version) }
    // periphery:ignore
    static func watchos(_ version: String) -> Self { .init(name: .watchos, version: version) }
    // periphery:ignore
    static func tvos(_ version: String) -> Self { .init(name: .tvos, version: version) }
}


extension Platform {
    init?(from dto: Manifest.Platform) {
        guard let name = Platform.Name(rawValue: dto.platformName.rawValue) else { return nil }
        self.name = name
        self.version = dto.version
    }
}


extension Platform: CustomStringConvertible {
    var description: String {
        switch name {
            case .android:
                return "Android \(version)"
            case .custom:
                return "Custom \(version)"
            case .driverkit:
                return "DriverKit \(version)"
            case .ios:
                return "iOS \(version)"
            case .linux:
                return "Linux \(version)"
            case .macos, .maccatalyst:
                return "macOS \(version)"
            case .openbsd:
                return "OpenBSD \(version)"
            case .tvos:
                return "tvOS \(version)"
            case .visionos:
                return "visionOS \(version)"
            case .wasi:
                return "WASI \(version)"
            case .watchos:
                return "watchOS \(version)"
            case .windows:
                return "Windows \(version)"
        }
    }
}
