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
import Vapor

enum DocumentationErrorPage {

    final class View: PublicPage {
        let error: AbortError

        init(path: String, error: AbortError) {
            self.error = error
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Documentation Error"
        }

        override func content() -> Node<HTML.BodyContext> {
            .section(
                .class("error_message"),
                .h4(.text("Documentation for this package is not yet available")),
                .p("For newly added packages or packages which have only just started to adopt DocC documentation, it can take a short while for documentation to be generated and available."),
                .p(
                    .text("If this error persists, please "),
                    .a(
                        .href(ExternalURL.raiseNewIssue),
                        "raise an issue"
                    ),
                    .text(".")
                ),
                .p(
                    .text("From here, you'll want to "),
                    .a(
                        .href(SiteURL.home.relativeURL()),
                        "go to the home page"
                    ),
                    .text(" or "),
                    .a(
                        .href(SiteURL.search.relativeURL()),
                        "search for a package"
                    ),
                    .text(".")
                )
            )
        }

    }

}
