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


extension PackageShow.Model {
    
    struct History: Equatable {
        var since: String
        var commitCount: Link
        var releaseCount: Link
    }
    
    struct Activity: Equatable {
        var openIssuesCount: Int
        var openIssues: Link?
        var openPullRequests: Link?
        var lastIssueClosedAt: String?
        var lastPullRequestClosedAt: String?
    }
    
    struct ProductCounts: Equatable {
        var libraries: Int
        var executables: Int
    }
    
    struct ReleaseInfo: Equatable {
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
    
    struct BuildInfo<T: Equatable>: Equatable {
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
    
    enum PlatformCompatibility: BuildResultParameter {
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

        @available(*, deprecated)
        var note: String? {
            switch self {
                case .macos, .ios, .linux, .tvos, .watchos:
                    return nil
            }
        }
    }

    struct Reference: Equatable {
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
    
    struct BuildStatusRow<T: Equatable>: Equatable {
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
    
    struct NamedBuildResults<T: Equatable>: Equatable {
        var referenceName: String
        var results: T
    }

    struct SwiftVersionResults: Equatable {
        var v5_3: BuildResult<SwiftVersion>
        var v5_4: BuildResult<SwiftVersion>
        var v5_5: BuildResult<SwiftVersion>
        var v5_6: BuildResult<SwiftVersion>

        init(status5_3: BuildStatus,
             status5_4: BuildStatus,
             status5_5: BuildStatus,
             status5_6: BuildStatus) {
            self.v5_3 = .init(parameter: .v5_3, status: status5_3)
            self.v5_4 = .init(parameter: .v5_4, status: status5_4)
            self.v5_5 = .init(parameter: .v5_5, status: status5_5)
            self.v5_6 = .init(parameter: .v5_6, status: status5_6)
        }

        var cells: [BuildResult<SwiftVersion>] { [v5_6, v5_5, v5_4, v5_3 ] }
    }

    struct PlatformResults: Equatable {
        var ios: BuildResult<PlatformCompatibility>
        var linux: BuildResult<PlatformCompatibility>
        var macos: BuildResult<PlatformCompatibility>
        var tvos: BuildResult<PlatformCompatibility>
        var watchos: BuildResult<PlatformCompatibility>

        init(iosStatus: BuildStatus,
             linuxStatus: BuildStatus,
             macosStatus: BuildStatus,
             tvosStatus: BuildStatus,
             watchosStatus: BuildStatus) {
            self.ios = .init(parameter: .ios, status: iosStatus)
            self.linux = .init(parameter: .linux, status: linuxStatus)
            self.macos = .init(parameter: .macos, status: macosStatus)
            self.tvos = .init(parameter: .tvos, status: tvosStatus)
            self.watchos = .init(parameter: .watchos, status: watchosStatus)
        }

        var cells: [BuildResult<PlatformCompatibility>] { [ios, macos, linux, tvos, watchos] }
    }

    enum BuildStatus: String, Equatable {
        case compatible
        case incompatible
        case unknown

        var cssClass: String {
            self.rawValue
        }
    }

    struct BuildResult<T: BuildResultParameter>: Equatable {
        var parameter: T
        var status: BuildStatus
        
        var headerNode: Node<HTML.BodyContext> {
            .div(
                .text(parameter.displayName),
                .unwrap(parameter.note) { .small(.text("(\($0))")) }
            )
        }
        
        var cellNode: Node<HTML.BodyContext> {
            .div(
                .class("\(status.cssClass)"),
                .title(title)
            )
        }
        
        var title: String {
            switch status {
                case .compatible:
                    return "Built successfully with \(parameter.longDisplayName)"
                case .incompatible:
                    return "Build failed with \(parameter.longDisplayName)"
                case .unknown:
                    return "No build information available for \(parameter.longDisplayName)"
            }
        }
    }
    
}


protocol BuildResultParameter: Equatable {
    var displayName: String { get }
    var longDisplayName: String { get }
    var note: String? { get }
}
