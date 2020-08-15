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
    }
    
    enum PlatformCompatibility: BuildResultParameter {
        case ios
        case linux
        case macos
        case macosArm
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
                case .macosArm:
                    return "macOS"
                case .tvos:
                    return "tvOS"
                case .watchos:
                    return "watchOS"
            }
        }

        var longDisplayName: String { displayName }

        var note: String? {
            switch self {
                case .macos:
                    return "intel"
                case .macosArm:
                    return "ARM"
                case .ios, .linux, .tvos, .watchos:
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
                .i(.class("icon \(cssClass)")),
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
        
        var label: Node<HTML.BodyContext> {
            guard !references.isEmpty else { return .empty }
            return .div(
                .class("row_label"),
                .div( // Note: It may look like there is a completely useless div here, but it's needed. I promise.
                    .div(
                        .group(references.map(\.node).joined(separator: .text(" and ")))
                    )
                )
            )
        }
    }
    
    struct NamedBuildResults<T: Equatable>: Equatable {
        var referenceName: String
        var results: T
    }

    struct SwiftVersionResults: Equatable {
        var v4_2: BuildResult<SwiftVersion>
        var v5_0: BuildResult<SwiftVersion>
        var v5_1: BuildResult<SwiftVersion>
        var v5_2: BuildResult<SwiftVersion>
        var v5_3: BuildResult<SwiftVersion>

        init(status4_2: BuildStatus,
             status5_0: BuildStatus,
             status5_1: BuildStatus,
             status5_2: BuildStatus,
             status5_3: BuildStatus) {
            self.v4_2 = .init(parameter: .v4_2, status: status4_2)
            self.v5_0 = .init(parameter: .v5_0, status: status5_0)
            self.v5_1 = .init(parameter: .v5_1, status: status5_1)
            self.v5_2 = .init(parameter: .v5_2, status: status5_2)
            self.v5_3 = .init(parameter: .v5_3, status: status5_3)
        }

        var cells: [BuildResult<SwiftVersion>] { [v5_3, v5_2, v5_1, v5_0, v4_2 ] }
    }

    struct PlatformResults: Equatable {
        var ios: BuildResult<PlatformCompatibility>
        var linux: BuildResult<PlatformCompatibility>
        var macos: BuildResult<PlatformCompatibility>
        var macosArm: BuildResult<PlatformCompatibility>
        var tvos: BuildResult<PlatformCompatibility>
        var watchos: BuildResult<PlatformCompatibility>

        init(iosStatus: BuildStatus,
             linuxStatus: BuildStatus,
             macosStatus: BuildStatus,
             macosArmStatus: BuildStatus,
             tvosStatus: BuildStatus,
             watchosStatus: BuildStatus) {
            self.ios = .init(parameter: .ios, status: iosStatus)
            self.linux = .init(parameter: .linux, status: linuxStatus)
            self.macos = .init(parameter: .macos, status: macosStatus)
            self.macosArm = .init(parameter: .macosArm, status: macosArmStatus)
            self.tvos = .init(parameter: .tvos, status: tvosStatus)
            self.watchos = .init(parameter: .watchos, status: watchosStatus)
        }

        var cells: [BuildResult<PlatformCompatibility>] { [ios, macos, macosArm, linux, tvos, watchos] }
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
                .unwrap(parameter.note) { .element(named: "small", text: "(\($0))") }
            )
        }
        
        var cellNode: Node<HTML.BodyContext> {
            .div(
                .class("\(status.cssClass)"),
                .attribute(named: "title", value: title),
                .i(.class("icon matrix_\(status.cssClass)"))
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
