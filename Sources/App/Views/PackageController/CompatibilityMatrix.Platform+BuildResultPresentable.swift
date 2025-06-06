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


extension CompatibilityMatrix.Platform: BuildResultPresentable {
    var displayName: String {
        switch self {
            case .android:
                return "Android"
            case .iOS:
                return "iOS"
            case .linux:
                return "Linux"
            case .macOS:
                return "macOS"
            case .tvOS:
                return "tvOS"
            case .visionOS:
                return "visionOS"
            case .wasm:
                return "Wasm"
            case .watchOS:
                return "watchOS"
        }
    }

    var longDisplayName: String {
        switch self {
            case .android, .macOS, .iOS, .linux, .tvOS, .visionOS, .watchOS:
                return displayName
            case .wasm:
                return "WebAssembly"
        }
    }

    var note: String? { nil }
}
