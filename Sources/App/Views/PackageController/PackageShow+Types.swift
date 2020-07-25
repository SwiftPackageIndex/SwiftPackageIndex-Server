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
    
    struct BuildInfo: Equatable {
        var stable: NamedBuildResults?
        var beta: NamedBuildResults?
        var latest: NamedBuildResults?
    }
    
    struct SwiftVersion: Equatable, Hashable, Comparable {
        static func < (lhs: SwiftVersion, rhs: SwiftVersion) -> Bool {
            lhs.displayName < rhs.displayName
        }
        
        var displayName: String
        var semVer: SemVer
        var isLatest: Bool
        var isBeta: Bool
        
        var note: String? {
            if isLatest { return "latest" }
            if isBeta { return "beta" }
            return nil
        }
        
        static let v4_2: Self = .init(displayName: "4.2",
                                      semVer: .init(4, 2, 0),
                                      isLatest: false,
                                      isBeta: false)
        static let v5_0: Self = .init(displayName: "5.0",
                                      semVer: .init(5, 0, 0),
                                      isLatest: false,
                                      isBeta: false)
        static let v5_1: Self = .init(displayName: "5.1",
                                      semVer: .init(5, 1, 0),
                                      isLatest: false,
                                      isBeta: false)
        static let v5_2: Self = .init(displayName: "5.2",
                                      semVer: .init(5, 2, 0),
                                      isLatest: true,
                                      isBeta: false)
        static let v5_3: Self = .init(displayName: "5.3",
                                      semVer: .init(5, 3, 0),
                                      isLatest: false,
                                      isBeta: true)
    }
    
    struct Reference: Equatable {
        var name: String
        var kind: Kind
        
        enum Kind: String {
            case beta
            case branch
            case stable
        }
        
        var node: Node<HTML.BodyContext> {
            .span(
                .class("\(kind)"),
                .i(.class("icon \(kind)")),
                .text(name)
            )
        }
    }
    
    struct BuildStatusRow: Equatable {
        var references: [Reference]
        var results: BuildResults
        
        init(references: [Reference], results: BuildResults) {
            self.references = references
            self.results = results
        }
        
        init(namedResult: NamedBuildResults, kind: Reference.Kind) {
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
    
    struct NamedBuildResults: Equatable {
        var referenceName: String
        var results: BuildResults
    }
    
    struct BuildResults: Equatable {
        var v4_2: BuildResult
        var v5_0: BuildResult
        var v5_1: BuildResult
        var v5_2: BuildResult
        var v5_3: BuildResult
        
        init(status4_2: BuildStatus,
             status5_0: BuildStatus,
             status5_1: BuildStatus,
             status5_2: BuildStatus,
             status5_3: BuildStatus) {
            self.v4_2 = .init(swiftVersion: .v4_2, status: status4_2)
            self.v5_0 = .init(swiftVersion: .v5_0, status: status5_0)
            self.v5_1 = .init(swiftVersion: .v5_1, status: status5_1)
            self.v5_2 = .init(swiftVersion: .v5_2, status: status5_2)
            self.v5_3 = .init(swiftVersion: .v5_3, status: status5_3)
        }
        
        var all: [BuildResult] { [v4_2, v5_0, v5_1, v5_2, v5_3] }
    }
    
    enum BuildStatus: String, Equatable {
        case success
        case failed
        case unknown
    }
    
    struct BuildResult: Equatable {
        var swiftVersion: SwiftVersion
        var status: BuildStatus
        
        var headerNode: Node<HTML.BodyContext> {
            .div(
                .text(swiftVersion.displayName),
                .unwrap(swiftVersion.note) { .element(named: "small", text: "(\($0))") }
            )
        }
        
        var cellNode: Node<HTML.BodyContext> {
            .div(
                .class("\(status)"),
                .attribute(named: "title", value: title),
                .i(.class("icon build_\(status)"))
            )
        }
        
        var title: String {
            switch status {
                case .success:
                    return "Built successfully with Swift \(swiftVersion.displayName)"
                case .failed:
                    return "Build failed with Swift \(swiftVersion.displayName)"
                case .unknown:
                    return "No build information available for Swift \(swiftVersion.displayName)"
            }
        }
    }
    
}
