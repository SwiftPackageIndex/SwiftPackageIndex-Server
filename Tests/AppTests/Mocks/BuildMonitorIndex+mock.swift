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

@testable import App
import Foundation

extension Array where Element == BuildMonitorIndex.Model {
    static var mock: [BuildMonitorIndex.Model] {
        [
            .init(buildId: .id0,
                  createdAt: Current.date().adding(hours: -1),
                  packageName: "Leftpad",
                  repositoryOwnerName: "Dave Verwer",
                  platform: .macosXcodebuild,
                  swiftVersion: .init(5, 6, 0),
                  reference: .tag(.init(1, 0, 0), "1.0.0"),
                  referenceKind: .release,
                  status: .ok,
                  runner: .mac0),
            .init(buildId: .id1,
                  createdAt: Current.date().adding(hours: -2),
                  packageName: "Rester",
                  repositoryOwnerName: "Sven A. Schmidt",
                  platform: .linux,
                  swiftVersion: SwiftVersion(5, 6, 0),
                  reference: .tag(.init(1, 0, 0, "beta1", ""), "1.0.0-beta1"),
                  referenceKind: .preRelease,
                  status: .failed,
                  runner: .linux1),
            .init(buildId: .id2,
                  createdAt: Current.date().adding(hours: -3),
                  packageName: "AccessibilitySnapshotColorBlindness",
                  repositoryOwnerName: "James Sherlock",
                  platform: .linux,
                  swiftVersion: SwiftVersion(5, 5, 0),
                  reference: .branch("main"),
                  referenceKind: .defaultBranch,
                  status: .triggered,
                  runner: nil)
        ]
    }
}
