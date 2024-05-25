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
    enum Platform: String, Codable, Comparable, CaseIterable {
        // NB: case order is significant - it determines CaseInterable's allCases and is used to order entries in the matrix
        case iOS
        case macOS
        case visionOS
        case watchOS
        case tvOS
        case linux

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
            let all = Platform.allCases.compactMap { platform in results[platform].map { BuildResult(parameter: platform, status: $0) }  }
            assert(all.count == Platform.allCases.count, "mismatch in CompatibilityMatrix.Platform and all platform results count")
            return all
        }

        subscript(platform: Platform) -> Compatibility? {
            results[platform]
        }
    }

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
