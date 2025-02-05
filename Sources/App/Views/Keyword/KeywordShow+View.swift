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


enum KeywordShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Packages for keyword \(model.keyword)"
        }

        override func pageDescription() -> String? {
            let packagesClause = model.packages.count > 1 ? "\(model.packages.count) packages" : "1 package"
            return "The Swift Package Index is indexing \(packagesClause) for \(model.keyword)."
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: model.keyword)
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(
                    .class("trimmed"),
                    .text("Packages for keyword “\(model.keyword)”")
                ),
                .p(
                    .text("These packages are available as a package collection, "),
                    .a(
                        .href(SiteURL.packageCollections.relativeURL()),
                        "usable in Xcode or SwiftPM"
                    ),
                    .text(".")
                ),
                .copyableInputForm(buttonName: "Copy Package Collection URL",
                                   eventName: "Copy Package Collection URL Button",
                                   valueToCopy: SiteURL.packageCollectionKeyword(.value(model.keyword)).absoluteURL()),
                packageCollectionLimitNote(),
                .hr(.class("minor")),
                .ul(
                    .id("package-list"),
                    .group(
                        model.packages.map { .packageListItem(linkUrl: $0.url, packageName: $0.title, summary: $0.description, repositoryOwner: $0.repositoryOwner, repositoryName: $0.repositoryName, stars: $0.stars, lastActivityAt: $0.lastActivityAt, hasDocs: $0.hasDocs ?? false) }
                    )
                ),
                .if(model.page == 1 && !model.hasMoreResults,
                    .p(
                        .strong("\(model.packages.count) \("package".pluralized(for: model.packages.count)).")
                    )
                   ),
                .ul(
                    .class("pagination"),
                    .if(model.page > 1, .previousPage(model: model)),
                    .if(model.hasMoreResults, .nextPage(model: model))
                )
            )
        }

        private func packageCollectionLimitNote() -> Node<HTML.BodyContext> {
            guard model.totalPackageCount > Constants.maxKeywordPackageCollectionCount else { return .empty }
            return .p(
                .strong("Note: "),
                .text("Package collections are limited to \(Constants.maxKeywordPackageCollectionCount) packages. The “\(model.keyword)”  keyword currently has \(pluralizedCount: model.totalPackageCount, singular: "associated package"), so its package collection includes only the top \(Constants.maxKeywordPackageCollectionCount) packages by package score."
                )
            )
        }
    }
}


fileprivate extension Node where Context == HTML.ListContext {
    static func previousPage(model: KeywordShow.Model) -> Node<HTML.ListContext> {
        let parameters = [
            QueryParameter(key: "page", value: model.page - 1)
        ]
        return .li(
            .class("previous"),
            .a(
                .href(SiteURL.keywords(.value(model.keyword))
                        .relativeURL(parameters: parameters)),
                "Previous Page"
            )
        )
    }

    static func nextPage(model: KeywordShow.Model) -> Node<HTML.ListContext> {
        let parameters = [
            QueryParameter(key: "page", value: model.page + 1)
        ]
        return .li(
            .class("next"),
            .a(
                .href(SiteURL.keywords(.value(model.keyword))
                        .relativeURL(parameters: parameters)),
                "Next Page"
            )
        )
    }
}
