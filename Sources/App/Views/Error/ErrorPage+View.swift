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

enum ErrorPage {

    final class View: PublicPage {
        let model: Model


        init(path: String, error: AbortError) {
            self.model = Model(error)
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "\(model.errorMessage) &ndash; Error"
        }

        override func content() -> Node<HTML.BodyContext> {
            .section(
                .class("error-message"),
                .h4(.text(model.errorMessage)),
                model.errorInstructions,
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
