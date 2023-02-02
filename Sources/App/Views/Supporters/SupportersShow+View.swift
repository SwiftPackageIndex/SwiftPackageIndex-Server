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

extension SupportersShow {

    class View: PublicPage {
        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            return "Supporters"
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: "Supporters")
            ]
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .class("supporters"),
                .h2("Supporters"),
                .p(
                    .text("This project is entirely funded by the generous support of many companies and individuals around the Swift community. "),
                    .strong("Thank you so much"),
                    .text(" to everyone who supports this project. We couldn’t keep it running without you!")
                    ),
                .p(
                    .text("Please consider adding your name to the list below by "),
                    .a(
                        .href("https://github.com/sponsors/SwiftPackageIndex"),
                        "supporting the project with GitHub Sponsors"
                    ),
                    .text(". Or, if you are interested in corporate support , please "),
                    .a(
                        .href("mailto:contact@swiftpackageindex.com"),
                        "get in touch"
                    ),
                    .text(".")
                ),
                .hr(),
                model.corporateSupporters(),
                model.infrastructureSupporters(),
                model.communitySupporters()
            )
        }

        override func navMenuItems() -> [NavMenuItem] {
            [.sponsorCTA, .addPackage, .blog, .faq]
        }
    }
}
