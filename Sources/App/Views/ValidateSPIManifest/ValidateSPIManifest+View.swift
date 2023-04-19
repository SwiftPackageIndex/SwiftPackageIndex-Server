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

import CustomDump
import Plot
import SPIManifest
import Vapor


extension ValidateSPIManifest {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Validate a Swift Package Index manifest"
        }

        override func pageDescription() -> String? {
            """
            The SPI Manifest allows package authors to configure how their packages
            are indexed. Validate your manifests on this page.
            """
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(
                    .class("trimmed"),
                    .text("Validate a Swift Package Index manifest")
                ),
                .p(
                    "Swift Package Index manifest, or ", .code(".spi.yml"), " files, allow package authors to ",
                    "configure settings that control how the Swift Package Index checks platform and Swift ",
                    "version compatibility, builds package documentation, and displays package metadata. ",
                    .a(
                        .href(SiteURL.package(.value("SwiftPackageIndex"), .value("SPIManifest"), .documentation).relativeURL()),
                        .text("Learn more about the capabilities and syntax of this file")
                    ),
                    "."
                ),
                .turboFrame(id: "validate-manifest",
                            .form(
                                .action(SiteURL.validateSPIManifest.relativeURL()),
                                .method(.post),
                                .label(
                                    .p("Enter the contents of a ", .code(".spi.yml"), " file for validation:"),
                                    .textarea(
                                        .name("manifest"),
                                        .autofocus(true),
                                        .rows(15),
                                        .text(model.manifest)
                                    )
                                ),
                                .button(
                                    .type(.submit),
                                    .text("Validate")
                                )
                            ),
                            .unwrap(model.validationResult, { result in
                                    .div(
                                        .class("result \(result.cssClass)"),
                                        result.asHTML()
                                    )
                            })
                )
            )
        }

    }
}


extension ValidateSPIManifest.ValidationResult {
    func asHTML() -> Node<HTML.BodyContext> {
        switch self {
            case .valid(let manifest):
                var out = ""
                customDump(manifest, to: &out)
                return .group(
                    .text("Manifest is valid! This is how we parsed it:"),
                    .pre(.text(out))
                )
            case .invalid(let string):
                return .text(string)
        }
    }
}
