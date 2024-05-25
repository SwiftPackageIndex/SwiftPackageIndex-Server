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
    var compatibility: CompatibilityMatrix.Compatibility {
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
    func isCompatible(with other: CompatibilityMatrix.Platform) -> Bool {
        switch self {
            case .iOS:
                return other == .iOS
            case .macosSpm, .macosXcodebuild:
                return other == .macOS
            case .tvOS:
                return other == .tvOS
            case .watchOS:
                return other == .watchOS
            case .visionOS:
                return other == .visionOS
            case .linux:
                return other == .linux
        }
    }
}
