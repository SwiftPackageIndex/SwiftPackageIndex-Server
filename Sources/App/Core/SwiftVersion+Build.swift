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

extension SwiftVersion {
    // NB: Remember to remove any old builds from the database when *removing* a Swift
    // version here!
    // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1267#issuecomment-975379966
    // Patch versions are irrelevant here but the underlying type requires one, so use 0
    // in general.
    static let v5_4: Self = .init(5, 4, 0)
    static let v5_5: Self = .init(5, 5, 0)
    static let v5_6: Self = .init(5, 6, 0)
    static let v5_7: Self = .init(5, 7, 0)

    /// Currently supported swift versions for building
    static var allActive: [Self] {
        [.v5_4, .v5_5, .v5_6, .v5_7]
    }

    var xcodeVersion: String? {
        // NB: this is used for display purposes and not critical for compiler selection
        switch self {
            case .v5_4:
                return "Xcode 12.5"
            case .v5_5:
                return "Xcode 13.2.1"
            case .v5_6:
                return "Xcode 13.4.1"
            case .v5_7:
                return "Xcode 14.2"
            default:
                return nil
        }
    }

    var compatibility: SwiftVersion? {
       for version in SwiftVersion.allActive {
            if self.isCompatible(with: version) { return version }
        }
        return nil
    }
}
