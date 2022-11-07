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

// In a local development environment, appVersion will remain nil (as set here).
// In the staging development environment, appVersion is set to the commit hash of the deployed version.
// In production, appVersion is set either to released tag name, or to the commit hash if that does not exist.

// Note: If the definition of appVersion ever changes, the `gitlab-ci.yml` file also
// needs updating as this file is re-generated during the deployment process.

enum BuildRunner: String, CustomStringConvertible {
    // Note: Runner IDs can be found under "Runners", here:
    // https://gitlab.com/finestructure/swiftpackageindex-builder/-/settings/ci_cd

    case linux1 = "WmqMUs6e"
    case linux2 = "iE4SRjQi"
    case mac0 = "pMpxem39" // Retired on 30th March 2022
    case mac1 = "DVohN7oe" // Retired on 30th March 2022
    case mac2 = "eFGZxpyH" // Retired on 30th March 2022
    case mac3 = "DMJah_V-"
    case mac4 = "1hFCVExo"
//    case mac5 = "ogLoW6xX" // New runner ID because of fresh Ventura installation.
    case mac5 = "o86TiJKT"

    var description: String {
        switch self {
            case .linux1: return "Linux 1"
            case .linux2: return "Linux 2"
            case .mac0: return "Mac 0"
            case .mac1: return "Mac 1"
            case .mac2: return "Mac 2"
            case .mac3: return "Mac 3"
            case .mac4: return "Mac 4"
            case .mac5: return "Mac 5"
        }
    }
}
