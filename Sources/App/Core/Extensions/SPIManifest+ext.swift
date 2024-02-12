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


extension SPIManifest.Manifest {
    var docPairs: Set<BuildPair> {
        Set(
            BuildPair.all.compactMap {
                guard let swiftVersion = $0.manifestSwiftVersion,
                      documentationTargets(platform: $0.manifestPlatform, swiftVersion: swiftVersion) != nil
                else { return nil }
                return $0
            }
        )
    }
}
