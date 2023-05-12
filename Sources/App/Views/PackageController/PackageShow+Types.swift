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

import Plot


#warning("rename to BuildResultPresentable")
#warning("move to better location")
protocol BuildResultParameter: Equatable {
    var displayName: String { get }
    var longDisplayName: String { get }
    var note: String? { get }
}


extension PackageShow {
    struct Reference: Codable, Equatable {
        var name: String
        var kind: App.Version.Kind

        var node: Node<HTML.BodyContext> {
            .span(
                .class(cssClass),
                .text(name)
            )
        }

        var cssClass: String {
            switch kind {
                case .defaultBranch: return "branch"
                case .preRelease: return "beta"
                case .release: return "stable"
            }
        }
    }

    struct BuildStatusRow<T: Codable & Equatable>: Codable, Equatable {
        var references: [Reference]
        var results: T

        init(references: [Reference], results: T) {
            self.references = references
            self.results = results
        }

        init(namedResult: API.PackageController.GetRoute.Model.NamedBuildResults<T>, kind: App.Version.Kind) {
            self.references = [.init(name: namedResult.referenceName, kind: kind)]
            self.results = namedResult.results
        }

        var labelParagraphNode: Node<HTML.BodyContext> {
            guard !references.isEmpty else { return .empty }
            return .p(
                .group(
                    listPhrase(nodes: references.map(\.node))
                )
            )
        }
    }
}
