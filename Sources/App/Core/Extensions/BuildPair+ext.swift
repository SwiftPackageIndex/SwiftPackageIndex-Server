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


extension BuildPair {
    var manifestPlatform: SPIManifest.Platform {
        switch platform {
            case .iOS:
                return .iOS
            case .linux:
                return .linux
            case .macosSpm:
                return .macosSpm
            case .macosXcodebuild:
                return .macosXcodebuild
            case .tvOS:
                return .tvOS
            case .visionOS:
                return .visionOS
            case .watchOS:
                return .watchOS
            case .wasm:
                return .wasm
            case .android:
                return .android
        }
    }

    var manifestSwiftVersion: SPIManifest.SwiftVersion? {
        .init(major: swiftVersion.major, minor: swiftVersion.minor)
    }
}
