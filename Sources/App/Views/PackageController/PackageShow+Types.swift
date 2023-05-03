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


extension PackageShow.Model {

    struct History: Codable, Equatable {
        var since: String
        var commitCount: Link
        var releaseCount: Link
    }

    struct Activity: Codable, Equatable {
        var openIssuesCount: Int
        var openIssues: Link?
        var openPullRequests: Link?
        var lastIssueClosedAt: String?
        var lastPullRequestClosedAt: String?
    }

    struct ProductCounts: Codable, Equatable {
        var libraries: Int
        var executables: Int
        var plugins: Int
    }

    struct ReleaseInfo: Codable, Equatable {
        var stable: DatedLink?
        var beta: DatedLink?
        var latest: DatedLink?
    }

    struct Version: Equatable {
        var link: Link
        var swiftVersions: [String]
        var platforms: [Platform]
    }

    struct LanguagePlatformInfo: Equatable {
        var stable: Version?
        var beta: Version?
        var latest: Version?
    }

    struct BuildInfo<T: Codable & Equatable>: Codable, Equatable {
        var stable: NamedBuildResults<T>?
        var beta: NamedBuildResults<T>?
        var latest: NamedBuildResults<T>?

        init?(stable: PackageShow.Model.NamedBuildResults<T>? = nil,
              beta: PackageShow.Model.NamedBuildResults<T>? = nil,
              latest: PackageShow.Model.NamedBuildResults<T>? = nil) {
            // require at least one result to be non-nil
            guard stable != nil || beta != nil || latest != nil else { return nil }
            self.stable = stable
            self.beta = beta
            self.latest = latest
        }
    }

    enum PlatformCompatibility: Codable, BuildResultParameter {
        case ios
        case linux
        case macos
        case tvos
        case watchos

        var displayName: String {
            switch self {
                case .ios:
                    return "iOS"
                case .linux:
                    return "Linux"
                case .macos:
                    return "macOS"
                case .tvos:
                    return "tvOS"
                case .watchos:
                    return "watchOS"
            }
        }

        var longDisplayName: String {
            switch self {
                case .macos, .ios, .linux, .tvos, .watchos:
                    return displayName
            }
        }

        var note: String? {
            nil
        }
    }

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

        init(namedResult: NamedBuildResults<T>, kind: App.Version.Kind) {
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

    struct NamedBuildResults<T: Codable & Equatable>: Codable, Equatable {
        var referenceName: String
        var results: T
    }

}


protocol BuildResultParameter: Equatable {
    var displayName: String { get }
    var longDisplayName: String { get }
    var note: String? { get }
}
