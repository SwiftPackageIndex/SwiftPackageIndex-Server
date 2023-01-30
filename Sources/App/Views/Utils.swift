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
import Plot


// MARK: - Conjunction

func listPhrase(opening: Node<HTML.BodyContext> = "",
                nodes: [Node<HTML.BodyContext>],
                ifEmpty: Node<HTML.BodyContext>? = nil,
                conjunction: Node<HTML.BodyContext> = " and ",
                closing: Node<HTML.BodyContext> = "") -> [Node<HTML.BodyContext>] {
    switch nodes.count {
        case 0:
            return ifEmpty.map { [$0] } ?? []
        case 1:
            return [opening, nodes[0], closing]
        case 2:
            return [opening, nodes[0], conjunction, nodes[1], closing]
        default:
            let start: [Node<HTML.BodyContext>]
                = [opening, nodes.first!]
            let middle: [[Node<HTML.BodyContext>]] = nodes[1..<(nodes.count - 1)].map {
                [", ", $0]
            }
            let end: [Node<HTML.BodyContext>] =
                [",", conjunction, nodes.last!, closing]
            return middle.reduce(start) { $0 + $1 } + end
    }
}


// MARK: - View helpers

func makeLink(packageUrl: String, version: Version) -> Link? {
    let linkUrl: String
    switch version.reference {
        case .branch:
            linkUrl = packageUrl
        case .tag(_ , let v):
            linkUrl = packageUrl.droppingGitExtension + "/releases/tag/\(v)"
    }
    return .init(label: "\(version.reference)", url: linkUrl)
}

func makeDatedLink(packageUrl: String, version: Version,
                   keyPath: KeyPath<Version, Date>) -> DatedLink? {
    guard let link = makeLink(packageUrl: packageUrl, version: version)
    else { return nil }
    return .init(date: "\(date: version[keyPath: keyPath], relativeTo: Current.date())",
                 link: link)
}
