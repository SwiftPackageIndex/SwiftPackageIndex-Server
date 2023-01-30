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


extension PackageReleases.Model {
    static var mock: PackageReleases.Model {
        .init(releases: [
            // Standard release
            .init(
                title: "v1.0.0",
                date: "Released 14 days ago",
                html: """
                <h2>Added</h2>
                <ul>
                    <li>A really helpful feature everybody asked for</li>
                    <li>A feature I thought would be easier than it was</li>
                    <li>A feature Apple is pushing really hard</li>
                </ul>
                <h2>Fixed</h2>
                <p>Nothing! This pretend package is perfect.</p>
                """,
                link: "https://github.com/Sherlouk/swift-snapshot-testing-stitch/releases/tag/1.0.0"
            ),

            // Release where HTML contains duplicated version (which will be removed)
            .init(
                title: "v0.0.2",
                date: "Released 21 days ago",
                html: """
                <h2>v0.0.2 - Electric Boogaloo</h2>
                <p>Some extra release notes.</p>
                """,
                link: "https://github.com/Sherlouk/swift-snapshot-testing-stitch/releases/tag/0.0.0"
            ),

            // Release with no notes (fallback message)
            .init(
                title: "v0.0.1",
                date: "Released 1 month ago",
                html: nil,
                link: "https://github.com/Sherlouk/swift-snapshot-testing-stitch/releases/tag/0.0.0"
            ),
        ])
    }
}
