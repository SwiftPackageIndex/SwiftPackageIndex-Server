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


struct SignificantBuilds {
    struct BuildInfo: Equatable {
        var swiftVersion: SwiftVersion
        var platform: Build.Platform
        var status: Build.Status

        init(_ swiftVersion: SwiftVersion, _ platform: Build.Platform, _ status: Build.Status) {
            self.swiftVersion = swiftVersion
            self.platform = platform
            self.status = status
        }
    }

    var builds: [BuildInfo]

    init(buildInfo: [(SwiftVersion, Build.Platform, Build.Status)]) {
        self.builds = buildInfo.map(BuildInfo.init)
    }
}


extension SignificantBuilds {
    enum CompatibilityResult<Value: Equatable>: Equatable {
        case available([Value])
        case pending

        var values: [Value]? {
            switch self {
                case .available(let values):
                    return values
                case .pending:
                    return nil
            }
        }
    }

    /// Returns platform compatibility across a package's significant versions.
    /// - Returns: A `CompatibilityResult` of `Platform`
    func platformCompatibility() -> CompatibilityResult<Build.Platform> {
        if builds.allSatisfy({ $0.status == .triggered }) { return .pending }

        let builds = builds
            .filter { $0.status == .ok }
        let compatibility = Build.Platform.allActive.map { platform -> (Build.Platform, Bool) in
            for build in builds {
                if build.platform == platform {
                    return (platform, true)
                }
            }
            return (platform, false)
        }
        return .available(
            compatibility
                .filter { $0.1 }
                .map { $0.0 }
        )
    }

    /// Returns swift versions compatibility across a package's significant versions.
    /// - Returns: A `CompatibilityResult` of `SwiftVersion`
    func swiftVersionCompatibility() -> CompatibilityResult<SwiftVersion> {
        if builds.allSatisfy({ $0.status == .triggered }) { return .pending }

        let builds = builds
            .filter { $0.status == .ok }
        let compatibility = SwiftVersion.allActive.map { swiftVersion -> (SwiftVersion, Bool) in
            for build in builds {
                if build.swiftVersion.isCompatible(with: swiftVersion) {
                    return (swiftVersion, true)
                }
            }
            return (swiftVersion, false)
        }
        return .available(
            compatibility
                .filter { $0.1 }
                .map { $0.0 }
        )
    }
}
