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
            let packagesClause = model.packages.count > 1 ? "1 package" : "\(model.packages.count) packages"
            return "The Swift Package Index is indexing \(packagesClause) authored by \(model.ownerName)."
        }
        
        func starsText(stars: Int) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let number = formatter.string(from: NSNumber(value: stars))
            
            return "\(number) stars"
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
                .form(
                    .class("copyable_input"),
                    .input(
                        .type(.text),
                        .data(named: "button-name", value: "Copy Package Collection URL"),
                        .data(named: "event-name", value: "Copy Package Collection URL Button"),
                        .value(SiteURL.packageCollection(.value(model.owner)).absoluteURL()),
                        .readonly(true)
                    )
                ),
                .hr(.class("minor")),
                .ul(
                    .id("package_list"),
                    .group(
                        model.packages.map { package -> Node<HTML.ListContext> in
                            .li(
                                .a(
                                    .href(package.url),
                                    .class("two_column"),
                                    .div(
                                        .h4(.text(package.title)),
                                        .p(.text(package.description))
                                    ),
                                    .p(
                                        .span(.id("star_text")),
                                        .text(starsText(stars: package.stars))
                                    )
                                )
                            )
                        }
                    )
                ),
                .p(
                    .strong("\(model.packages.count) \("package".pluralized(for: model.packages.count)).")
                )
            )
        }
    }

}
