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

import Foundation


struct Platform: Codable, Equatable {
    enum Name: String, Codable, Equatable, CaseIterable {
        case ios
        case macos
        case watchos
        case tvos
    }
    var name: Name
    var version: String
    
    static func ios(_ version: String) -> Self { .init(name: .ios, version: version) }
    static func macos(_ version: String) -> Self { .init(name: .macos, version: version) }
    static func watchos(_ version: String) -> Self { .init(name: .watchos, version: version) }
    static func tvos(_ version: String) -> Self { .init(name: .tvos, version: version) }
}


extension Platform {
    init?(from dto: Manifest.Platform) {
        guard let name = Platform.Name(rawValue: dto.platformName.rawValue) else { return nil }
        self.name = name
        self.version = dto.version
    }
}


extension Platform.Name: CustomStringConvertible {
    var description: String {
        switch self {
            case .ios:
                return "iOS"
            case .macos:
                return "macOS"
            case .watchos:
                return "watchOS"
            case .tvos:
                return "tvOS"
        }
    }
}

extension Platform: CustomStringConvertible {
    var description: String {
        "\(name) \(version)"
    }
}
