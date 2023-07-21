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

    struct RepoTripel {
        var owner: String
        var name: String
        var branch: String
    }

    enum Model {
        case noReadme
        case readme(url: String, repoTripel: RepoTripel, readmeElement: Element?)
        case cacheLookupFailed(url: String)

        enum BaseReadmeUrlFileType: String {
            case raw
            case blob
        }

        init(url: String, repositoryOwner: String, repositoryName: String, defaultBranch: String, readme: String) {
            let repoTripel = RepoTripel(owner: repositoryOwner, name: repositoryName, branch: defaultBranch)
            self = .readme(
                url: url,
                repoTripel: repoTripel,
                readmeElement: Self.processReadme(readme, repoTripel)
            )
        }

        var readmeHtml: String? {
            switch self {
                case .noReadme, .cacheLookupFailed:
                    return nil
                case let .readme(url: _, repoTripel: _, readmeElement: element):
                    return try? element?.html()
            }
        }

        var readmeUrl: String? {
            switch self {
                case .noReadme:
                    return nil
                case let .readme(url: url, repoTripel: _, readmeElement: _), let .cacheLookupFailed(url: url):
                    return url
            }
        }

        static func processReadme(_ rawReadme: String, _ repoTripel: RepoTripel) -> Element? {
            guard let readmeElement = extractReadmeElement(rawReadme) else { return nil }
            processRelativeImages(readmeElement, repoTripel)
            processRelativeLinks(readmeElement, repoTripel)
            return readmeElement
        }

        static func extractReadmeElement(_ rawReadme: String) -> Element? {
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

        static func processRelativeImages(_ element: Element, _ repoTripel: RepoTripel) {
            do {
                let imageElements = try element.select("img")
                for imageElement in imageElements {
                    if let imageUrl = URL(withPotentiallyUnencodedPath: try imageElement.attr("src")),
                       let absoluteUrl = fixRelativeUrl(imageUrl, repoTripel, fileType: .raw) {
                        try imageElement.attr("src", absoluteUrl)
                    }
                }
            } catch {
                // Errors are being intentionally eaten here. The worst that can happen if the
                // HTML selection/parsing fails is that relative images don't get corrected.
                return
            }
        }

        static func processRelativeLinks(_ element: Element, _ repoTripel: RepoTripel) {
            do {
                let linkElements = try element.select("a")
                for linkElement in linkElements {
                    if let linkUrl = URL(withPotentiallyUnencodedPath: try linkElement.attr("href")),
                       let absoluteUrl = fixRelativeUrl(linkUrl, repoTripel, fileType: .blob) {
                        try linkElement.attr("href", absoluteUrl)
                    }
                }
            } catch {
                // Errors are being intentionally eaten here. The worst that can happen if the
                // HTML selection/parsing fails is that relative links don't get corrected.
                return
            }
        }

        static func fixRelativeUrl(_ url: URL, _ repoTripel: RepoTripel, fileType: BaseReadmeUrlFileType) -> String? {
            // If this is not a relative URL return nil so that no link replacement happens.
            guard url.host == nil, url.path.isEmpty == false else { return nil }

            // Assume all links are relative to GitHub as that's the only current source for README data.
            let baseUrl = "https://github.com/"
            let basePath = "\(repoTripel.owner)/\(repoTripel.name)/\(fileType.rawValue)/\(repoTripel.branch)"
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
