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

import Foundation
import Vapor
import SwiftSoup

extension PackageReadme {

    struct Model: Equatable {
        var url: String?
        var repositoryOwner: String?
        var repositoryName: String?
        var defaultBranch: String?
        private var readmeElement: Element?

        enum BaseReadmeUrlFileType: String {
            case raw
            case blob
        }

        internal init(url: String?, repositoryOwner: String?, repositoryName: String?, defaultBranch: String?, readme: String?) {
            self.url = url
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
            self.defaultBranch = defaultBranch
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
                let bodyFragment = try SwiftSoup.parseBodyFragment(rawReadme)
                let readmeElements = try bodyFragment.select("#readme article")
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
                    if let imageUrl = URL(withPotentiallyUnencodedPath: try imageElement.attr("src")),
                       let absoluteUrl = fixRelativeUrl(imageUrl, fileType: .raw) {
                        try imageElement.attr("src", absoluteUrl)
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
                    if let linkUrl = URL(withPotentiallyUnencodedPath: try linkElement.attr("href")),
                       let absoluteUrl = fixRelativeUrl(linkUrl, fileType: .blob) {
                        try linkElement.attr("href", absoluteUrl)
                    }
                }
            } catch {
                // Errors are being intentionally eaten here. The worst that can happen if the
                // HTML selection/parsing fails is that relative links don't get corrected.
                return
            }
        }

        func fixRelativeUrl(_ url: URL, fileType: BaseReadmeUrlFileType) -> String? {
            // If this is not a relative URL, or if any of the necessary parameters are
            // missing, return nil so that no link replacement happens.
            guard url.host == nil && url.path.isEmpty == false,
                  let repositoryOwner = repositoryOwner,
                  let repositoryName = repositoryName,
                  let defaultBranch = defaultBranch
            else { return nil }

            // Assume all links are relative to GitHub as that's the only current source for README data.
            let baseUrl = "https://github.com/"
            let basePath = "\(repositoryOwner)/\(repositoryName)/\(fileType.rawValue)/\(defaultBranch)"
            if url.path.starts(with: "/") {
                return baseUrl + basePath + url.absoluteString
            } else {
                return baseUrl + basePath + "/" + url.absoluteString
            }
        }

    }
}

extension URL {
    init?(withPotentiallyUnencodedPath string: String) {
        if let url = URL(string: string) {
            self = url
        } else if let encodedString = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedUrl = URL(string: encodedString) {
            self = encodedUrl
        } else {
            return nil
        }
    }
}
