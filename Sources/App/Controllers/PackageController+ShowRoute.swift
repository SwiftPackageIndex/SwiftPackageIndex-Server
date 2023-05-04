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

import Fluent
import SQLKit
import Vapor


// MARK: - "private" helper extensions
// Ideally these would be declared "private" but we need access from tests

extension Array where Element == PackageController.BuildsRoute.BuildInfo {
    var buildStatus: API.PackageController.GetRoute.Model.BuildStatus {
        guard !isEmpty else { return .unknown }
        if anySucceeded {
            return .compatible
        } else {
            return anyPending ? .unknown : .incompatible
        }
    }

    var noneSucceeded: Bool {
        allSatisfy { $0.status != .ok }
    }

    var anySucceeded: Bool {
        !noneSucceeded
    }

    var nonePending: Bool {
        allSatisfy { $0.status.isCompleted }
    }

    var anyPending: Bool {
        !nonePending
    }
}


extension Build.Platform {
    @available(*, deprecated)
    func _isCompatible(with other: PackageShow._Model.PlatformCompatibility) -> Bool {
        switch self {
            case .ios:
                return other == .ios
            case .macosSpm, .macosXcodebuild:
                return other == .macos
            case .tvos:
                return other == .tvos
            case .watchos:
                return other == .watchos
            case .linux:
                return other == .linux
        }
    }

    func isCompatible(with other: API.PackageController.GetRoute.Model.PlatformCompatibility) -> Bool {
        switch self {
            case .ios:
                return other == .ios
            case .macosSpm, .macosXcodebuild:
                return other == .macos
            case .tvos:
                return other == .tvos
            case .watchos:
                return other == .watchos
            case .linux:
                return other == .linux
        }
    }
}
