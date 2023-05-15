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


extension API.PackageController.GetRoute.Model.PlatformCompatibility: BuildResultPresentable {
    var displayName: String {
        switch self {
            case .ios:
                return "iOS"
            case .linux:
                return "Linux"
            case .macos:
                return "macOS"
            case .tvos:
                return "tvOS"
            case .watchos:
                return "watchOS"
        }
    }

    var longDisplayName: String {
        switch self {
            case .macos, .ios, .linux, .tvos, .watchos:
                return displayName
        }
    }

    var note: String? { nil }
}
