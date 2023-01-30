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

import Plot

enum BuildMonitorIndex {

    class View: PublicPage {

        let builds: [Model]

        init(path: String, builds: [Model]) {
            self.builds = builds
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Build System Monitor"
        }

        override func pageDescription() -> String? {
            "See what the platform and Swift version compatibility build system for the Swift Package Index is processing. The package index constantly looks for changes in packages and, when found, builds every package against a comprehensive set of Swift version and platform combinations."
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: "Build System Monitor")
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2("Recent Builds"),
                .p("The Swift Package Index determines Swift version and platform compatibility by running multiple builds against each version of every package. If you're curious which packages are currently processing through the build system, this list shows all recent build activity."),
                .div(
                    .class("build-monitor"),
                    .group(
                        builds.map { $0.buildMonitorItem() }
                    )
                )
            )
        }
    }
}
