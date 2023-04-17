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
import SPIManifest
import Vapor


enum ValidateSPIManifest {

    struct Validation: Content {
        var manifest: String
        var status: String?
    }

    class View: PublicPage {

        var validation: Validation = .init(manifest: placeholderManifest)

        init(req: Request) {
            super.init(path: req.url.path)
            if let validation = try? req.query.decode(Validation.self) {
                self.validation = validation
            }
        }

        override func pageTitle() -> String? {
            "SPI Manifest Validation"
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
                    .text("Swift Package Index manifest validation")
                ),
                .p(
                    "Swift Package Index manifests, or ", .code(".spi.yml"), " ",
                    "files, allow package authors to configure how their packages are indexed. ",
                    "You can find out more about the syntax in the ",
                    .a(
                        .href(SiteURL.package(.value("SwiftPackageIndex"), .value("SPIManifest"), .documentation).relativeURL()),
                        .text("“SPIManifest” documentation")
                    ),
                    "."
                ),
                .p(
                    .label(
                        .for(manifestElementID),
                        .p("Contents of your ", .code(".spi.yml"), " file:")
                    )
                ),
                .form(
                    .id("manifestValidationForm"),
                    .action(SiteURL.validateSPIManifest.relativeURL()),
                    .textarea(
                        .id(manifestElementID),
                        .name(manifestElementID),
                        .autofocus(true),
                        .rows(15),
                        .cols(60),
                        .text(self.validation.manifest)
                    ),
                    .br(),
                    .button(.attribute(named: "formmethod", value: "post"), .text("Submit"))
                ),
                .unwrap(self.validation.status, { status in
                        .group(
                            .br(),
                            .textarea(
                                .id("status"),
                                .rows(5),
                                .cols(60),
                                .readonly(true),
                                .text(status)
                            )
                        )
                }),
                .br(),
                .form(
                    .id("manifestResetForm"),
                    .action(SiteURL.validateSPIManifest.relativeURL()),
                    .button(.text("Reset"))
                )
            )
        }

    }

    static func validateManifest(req: Request) throws -> Response {
        struct Input: Content {
            var manifest: String
        }

        let input = try req.content.decode(Input.self)
        do {
            _ = try SPIManifest.Manifest(yml: input.manifest)
            return req.redirect(to: SiteURL.validateSPIManifest.relativeURL(parameters: [
                QueryParameter(key: "manifest", value: input.manifest),
                QueryParameter(key: "status", value: "✅ manifest is valid"),
            ]))
        } catch let error as DecodingError {
            return req.redirect(to: SiteURL.validateSPIManifest.relativeURL(parameters: [
                QueryParameter(key: "manifest", value: input.manifest),
                QueryParameter(key: "status", value: "\(error)"),
            ]))
        } catch {
            return req.redirect(to: SiteURL.validateSPIManifest.relativeURL(parameters: [
                QueryParameter(key: "manifest", value: input.manifest),
                QueryParameter(key: "status", value: error.localizedDescription),
            ]))
        }
    }

}


private let manifestElementID = "manifest"
private let placeholderManifest = """
version: 1
builder:
  configs:
    - documentation_targets: [Target1, Target2]
"""
