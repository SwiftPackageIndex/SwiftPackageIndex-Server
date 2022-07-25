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

import Foundation
import Vapor
import SwiftSoup

extension PackageReadme {
    
    struct Model: Equatable {
        var url: String?
        private var readmeElement: Element?

        internal init(url: String?, readme: String?) {
            self.url = url
            self.readmeElement = processReadme(readme)
        }

        var readme: String? {
            guard let readmeElement = readmeElement else { return nil }

            do {
                return try readmeElement.html()
            } catch {
                return nil
            }
        }

        func processReadme(_ rawReadme: String?) -> Element? {
            guard let rawReadme = rawReadme else { return nil }
            guard let readmeElement = extractReadmeElement(rawReadme) else { return nil }
            processRelativeImages(readmeElement)
            processRelativeLinks(readmeElement)
            return readmeElement
        }

        func extractReadmeElement(_ rawReadme: String) -> Element? {
            do {
                let htmlDocument = try SwiftSoup.parse(rawReadme)
                let readmeElements = try htmlDocument.select("#readme article")
                guard let articleElement = readmeElements.first()
                else { return nil } // There is no README if this element doesn't exist.
                return articleElement
            } catch {
                return nil
            }
        }

        func processRelativeImages(_ element: Element) {
            do {
                let imageElements = try element.select("img")
                for imageElement in imageElements {
                    guard let imageUrl = URL(string: try imageElement.attr("src"))
                    else { continue }

                    // Assume all images are relative to GitHub as that's the only current source for README data.
                    if (imageUrl.host == nil && imageUrl.path.starts(with: "/")) {
                        guard let newImageUrl = URL(string: "https://github.com\(imageUrl.absoluteString)")
                        else { continue }
                        try imageElement.attr("src", newImageUrl.absoluteString)
                    }
                }
            } catch {
                // Errors are being intentionally eaten here. The worst that can happen if the
                // HTML selection/parsing fails is that relative images don't get corrected.
                return
            }
        }

        func processRelativeLinks(_ element: Element) {
            do {
                let linkElements = try element.select("a")
                for linkElement in linkElements {
                    guard let linkUrl = URL(string: try linkElement.attr("href"))
                    else { continue }

                    // Assume all links are relative to GitHub as that's the only current source for README data.
                    if (linkUrl.host == nil && linkUrl.path.starts(with: "/")) {
                        guard let newLinkUrl = URL(string: "https://github.com\(linkUrl.absoluteString)")
                        else { continue }
                        try linkElement.attr("href", newLinkUrl.absoluteString)
                    }
                }
            } catch {
                // Errors are being intentionally eaten here. The worst that can happen if the
                // HTML selection/parsing fails is that relative links don't get corrected.
                return
            }
        }
    }
}

extension URL {
    init?(withPotentiallyPercentEncodedPath string: String) {
        if let url = URL(string: string) {
            self = url
        } else if let encodedString = string.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let encodedUrl = URL(string: encodedString) {
            self = encodedUrl
        } else {
            return nil
        }
    }
}
