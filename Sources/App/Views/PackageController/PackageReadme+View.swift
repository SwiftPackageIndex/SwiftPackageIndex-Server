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

import Vapor
import Plot

enum PackageReadme {
    
    class View: TurboFrame {
        
        let model: Model

        init(model: Model) {
            self.model = model
            super.init()
        }

        override func frameIdentifier() -> String {
            "readme_page"
        }

        override func frameContent() -> Node<HTML.BodyContext> {
            guard let readme = model.readme
            else { return blankReadmePlaceholder() }

            return .group(
                .spiReadme(
                    .raw(readme)
                )
            )
        }

        func blankReadmePlaceholder() -> Node<HTML.BodyContext> {
            guard let url = model.url
            else { return .p("This package does not have a README file.") }

            return .p(
                .text("This package's README file couldn't be loaded. Try "),
                .a(
                    .href(url),
                    .text("viewing it on GitHub")
                ),
                .text(".")
            )
        }
    }
    
}
