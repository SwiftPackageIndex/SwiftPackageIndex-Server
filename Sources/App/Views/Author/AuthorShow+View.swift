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

import Plot
import Foundation


enum AuthorShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Packages by \(model.ownerName)"
        }

        override func pageDescription() -> String? {
            let packagesClause = model.packages.count > 1 ? "\(model.packages.count) packages" : "1 package"
            return "The Swift Package Index is indexing \(packagesClause) authored by \(model.ownerName)."
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: model.ownerName)
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(
                    .class("trimmed"),
                    .text("Packages authored by \(model.ownerName)")
                ),
                .p(
                    .text("These packages are available as a package collection, "),
                    .a(
                        .href(SiteURL.packageCollections.relativeURL()),
                        "usable in Xcode 13 or the Swift Package Manager 5.5"
                    ),
                    .text(".")
                ),
                .copyableInputForm(buttonName: "Copy Package Collection URL",
                                   eventName: "Copy Package Collection URL Button",
                                   valueToCopy: SiteURL.packageCollection(.value(model.owner)).absoluteURL()),
                .hr(.class("minor")),
                .ul(
                    .id("package-list"),
                    .group(
                        model.packages.map { .packageListItem(linkUrl: $0.url, packageName: $0.title, summary: $0.description, repositoryOwner: $0.repositoryOwner, repositoryName: $0.repositoryName, stars: $0.stars, lastActivityAt: $0.lastActivityAt, hasDocs: $0.hasDocs ?? false) }
                    )
                ),
                .p(
                    .strong("\(model.packages.count) \("package".pluralized(for: model.packages.count)).")
                )
            )
        }
    }

}
