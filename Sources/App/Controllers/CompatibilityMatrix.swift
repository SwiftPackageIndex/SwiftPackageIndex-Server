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


enum CompatibilityMatrix {
    enum Compatibility: String, Codable, Equatable {
        case compatible
        case incompatible
        case unknown
    }

    struct BuildResult<T: Codable & Equatable>: Codable, Equatable {
        var parameter: T
        var status: Compatibility
    }
}


extension CompatibilityMatrix {
    enum Platform: String, Codable, Comparable, CaseIterable {
        // NB: case order is significant - it determines CaseInterable's allCases and is used to order entries in the matrix
        case iOS
        case macOS
        case visionOS
        case watchOS
        case tvOS
        case linux
        case wasm
        case android

        static func <(lhs: Self, rhs: Self) -> Bool { allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)! }
    }

    struct PlatformCompatibility: Codable, Equatable {
        var results: [Platform: Compatibility] = [:]

        init(results: [Platform: Compatibility] = [:]) {
            self.results = results
        }

        init(builds: [PackageController.BuildsRoute.BuildInfo]) {
            for platform in Platform.allCases {
                self.results[platform] = builds.filter { $0.platform.isCompatible(with:  platform) }.compatibility
            }
        }

        var all: [BuildResult<Platform>] {
            // The order of this array defines the order of the platforms in the build matrix on the package page.
            // Keep this aligned with the order in Build.Platform.allActive (which is the order of the builds on
            // the BuildIndex page).
            Platform.allCases.map { platform in
                BuildResult(parameter: platform, status: results[platform] ?? .unknown)
            }
        }

        subscript(platform: Platform) -> Compatibility? {
            results[platform]
        }
    }
}


extension CompatibilityMatrix {
    struct SwiftVersionCompatibility: Codable, Equatable {
        var results: [SwiftVersion: Compatibility] = [:]

        init(results: [SwiftVersion: Compatibility] = [:]) {
            self.results = results
        }

        init(builds: [PackageController.BuildsRoute.BuildInfo]) {
            for swiftVersion in SwiftVersion.allActive {
                self.results[swiftVersion] = builds.filter { $0.swiftVersion.isCompatible(with:  swiftVersion) }.compatibility
            }
        }

        var all: [BuildResult<SwiftVersion>] {
            // The order of this array defines the order of the Swift version in the build matrix on the package page.
            SwiftVersion.allActive.reversed().map { swiftVersion in
                BuildResult(parameter: swiftVersion, status: results[swiftVersion] ?? .unknown)
            }
        }

        subscript(swiftVersion: SwiftVersion) -> Compatibility? {
            results[swiftVersion]
        }
    }
}
