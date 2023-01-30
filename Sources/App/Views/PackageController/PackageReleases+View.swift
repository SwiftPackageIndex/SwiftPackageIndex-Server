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

import Vapor
import Plot

enum PackageReleases {

    class View: TurboFrame {

        let model: Model?

        init(model: Model?) {
            self.model = model
            super.init()
        }

        override func frameIdentifier() -> String {
            "releases_content"
        }

        override func frameContent() -> Node<HTML.BodyContext> {
            guard let releases = model?.releases
            else { return .p("This package has no release notes.") }

            return .group(
                .forEach(releases.enumerated()) { (index, release) in
                    group(forRelease: release, isLast: index == releases.count - 1)
                }
            )
        }

        func group(forRelease release: Model.Release, isLast: Bool) -> Node<HTML.BodyContext> {
            .group(
                .a(
                    .href(release.link),
                    .h2(.text(release.title))
                ),
                .unwrap(release.date) { .small(.text($0)) },
                .unwrap(release.html, { .raw($0) }, else: .p("This release has no notes.")),
                .if(isLast == false, .hr())
            )
        }
    }

}
