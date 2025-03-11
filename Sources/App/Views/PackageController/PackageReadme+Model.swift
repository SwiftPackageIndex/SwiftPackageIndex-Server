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

    typealias RepoTriple = (owner: String, name: String, branch: String)

    enum Model {
        case noReadme
        case readme(url: String, readmeElement: Element?)
        case cacheLookupFailed(url: String)

        init(url: String, repositoryOwner: String, repositoryName: String, defaultBranch: String, readme: String) {
            let repoTriple = (owner: repositoryOwner, name: repositoryName, branch: defaultBranch)
            self = .readme(
                url: url,
                readmeElement: Self.processReadme(readme, for: repoTriple)
            )
        }

        var readmeHtml: String? {
            switch self {
                case .noReadme, .cacheLookupFailed:
                    return nil
                case let .readme(url: _, readmeElement: element):
                    return try? element?.html()
            }
        }

        var readmeUrl: String? {
            switch self {
                case .noReadme:
                    return nil
                case let .readme(url: url, readmeElement: _), let .cacheLookupFailed(url: url):
                    return url
            }
        }

        static func processReadme(_ rawReadme: String, for repoTriple: RepoTriple) -> Element? {
            guard let readmeElement = Element.extractReadme(rawReadme) else { return nil }
            readmeElement.rewriteRelativeImages(to: repoTriple)
            readmeElement.rewriteRelativeLinks(to: repoTriple)
            readmeElement.fixInlineAnchors()
            readmeElement.fixProtectedCachedImages()
            readmeElement.disableTurboOnLinks()
            return readmeElement
        }
    }

}


extension Element {
    static func extractReadme(_ rawReadme: String) -> Element? {
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

    func rewriteRelativeImages(to repoTriple: PackageReadme.RepoTriple) {
        do {
            let imageElements = try select("img")
            for imageElement in imageElements {
                if let imageUrl = URL(withPotentiallyUnencodedPath: try imageElement.attr("src")),
                   let absoluteUrl = imageUrl.rewriteRelative(to: repoTriple, fileType: .raw) {
                    _ = try imageElement.attr("src", absoluteUrl)
                }
            }
        } catch {
            // Errors are being intentionally eaten here. The worst that can happen if the
            // HTML selection/parsing fails is that relative images don't get corrected.
        }
    }

    func rewriteRelativeLinks(to repoTriple: PackageReadme.RepoTriple) {
        do {
            let linkElements = try select("a")
            for linkElement in linkElements {
                if let linkUrl = URL(withPotentiallyUnencodedPath: try linkElement.attr("href")),
                   let absoluteUrl = linkUrl.rewriteRelative(to: repoTriple, fileType: .blob) {
                    _ = try linkElement.attr("href", absoluteUrl)
                }
            }
        } catch {
            // Errors are being intentionally eaten here. The worst that can happen if the
            // HTML selection/parsing fails is that links don't get corrected.
        }
    }

    func fixInlineAnchors() {
        do {
            let linkElements = try select("a")
            for linkElement in linkElements {
                let linkDestination = try linkElement.attr("href")
                if linkDestination.hasPrefix("#") {
                    // GitHub adds `user-content` to all anchor destinations but does not change
                    // the anchors that link to the destinations or match the case that it uses. :rollseyes:
                    _ = try linkElement.attr("href", "#user-content-\(linkDestination.dropFirst().lowercased())")
                }
            }
        } catch {
            // Errors are being intentionally eaten here. The worst that can happen if the
            // HTML selection/parsing fails is that links don't get corrected.
        }
    }

    func fixProtectedCachedImages() {
        do {
            let imageElements = try select("img[data-canonical-src]")
            for imageElement in imageElements {
                let originalUrl = try imageElement.attr("data-canonical-src")
                if originalUrl.hasPrefix("http") {
                    _ = try imageElement.attr("src", originalUrl)
                }
            }
        } catch {
            // Errors are being intentionally eaten here. The worst that can happen if the
            // HTML selection/parsing fails is that cached images don't get corrected.
        }
    }

    func disableTurboOnLinks() {
        do {
            let linkElements = try select("a")
            for linkElement in linkElements {
                // Disable Turbo on *all* link elements.
                _ = try linkElement.attr("data-turbo", "false")
            }
        } catch {
            // Errors are being intentionally eaten here. The worst that can happen if the
            // HTML selection/parsing fails is that links don't get corrected.
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

    enum BaseReadmeUrlFileType: String {
        case raw
        case blob
    }

    func rewriteRelative(to repoTriple: PackageReadme.RepoTriple, fileType: BaseReadmeUrlFileType) -> String? {
        // If this is not a relative URL return nil so that no link replacement happens.
        guard host == nil, path.isEmpty == false else { return nil }

        // Assume all links are relative to GitHub as that's the only current source for README data.
        let baseUrl = "https://github.com/"
        let basePath = "\(repoTriple.owner)/\(repoTriple.name)/\(fileType.rawValue)/\(repoTriple.branch)"
        if path.starts(with: "/") {
            return baseUrl + basePath + absoluteString
        } else {
            return baseUrl + basePath + "/" + absoluteString
        }
    }
}
