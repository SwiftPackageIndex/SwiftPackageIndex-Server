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


enum BuildShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "\(model.packageName) &ndash; Build Information"
        }

        override func pageDescription() -> String? {
            "Compatibility information for \(model.packageName). Check compatibility with \(model.buildInfo.swiftVersion.longDisplayName) on \(model.buildInfo.platform.displayName) with full build logs."
        }

        override func bodyComments() -> Node<HTML.BodyContext> {
            .comment(model.versionId.uuidString)
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: model.repositoryOwnerName, url: SiteURL.author(.value(model.repositoryOwner)).relativeURL()),
                Breadcrumb(title: model.packageName, url: SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .none).relativeURL()),
                Breadcrumb(title: "Build Results", url: SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                Breadcrumb(title: "\(model.buildInfo.swiftVersion.longDisplayName) on \(model.buildInfo.platform.displayName) at \(model.reference)"),
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Build Information"),
                .p(
                    .strong(
                        .class(model.buildInfo.status.cssClass),
                        .text(model.buildInfo.status.description)
                    ),
                    .text(model.buildInfo.status.joiningClause),
                    .a(
                        .href(model.packageURL),
                        .text(model.packageName)
                    ),
                    .text(" with "),
                    .strong(.text(model.buildInfo.swiftVersion.longDisplayName)),
                    .text(" for "),
                    .strong(.text(model.buildInfo.platform.displayName)),
                    .unwrap(model.buildInfo.xcodeVersion) {
                        .group(
                            .text(" using "),
                            .strong(.text($0)),
                            .text(" at "),
                            .strong(.text(model.reference))
                        )
                    },
                    .text(".")
                ),
                .h3("Build Command"),
                .pre(
                    .code(
                        .text(model.buildInfo.buildCommand)
                    )
                ),
                .h3("Build Log"),
                .pre(
                    .id("build-log"),
                    .code(
                        .text(model.buildInfo.logs)
                    )
                ),
                .unwrap(model.buildInfo.runner, {
                    .p(
                        .strong("Build Machine:"),
                        .text(" \($0)")
                    )
                })
            )
        }
    }

}


private extension Build.Status {

    var joiningClause: String {
        switch self {
            case .ok: return " build of "
            case .failed: return " to build "
            case .triggered: return " a build of "
            case .infrastructureError, .timeout: return " while building "
        }
    }

    var cssClass: String {
        switch self {
            case .ok: return "green"
            case .failed: return "red"
            case .infrastructureError, .triggered, .timeout: return ""
        }
    }
}
