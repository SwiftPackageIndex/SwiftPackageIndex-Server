import DependencyResolution
import Fluent
import SQLKit
import Vapor


extension API.PackageController {
    typealias PackageResult = Joined5<Package, Repository, DefaultVersion, ReleaseVersion, PreReleaseVersion>

    enum GetRoute {

        /// Assembles individual queries and transforms them into model structs.
        /// - Parameters:
        ///   - database: `Database`
        ///   - owner: repository owner
        ///   - repository: repository name
        /// - Returns: model structs
        static func query(on database: Database, owner: String, repository: String) async throws -> (model: Model, schema: PackageSchema) {
            let packageResult = try await PackageResult.query(on: database,
                                                              owner: owner,
                                                              repository: repository)
            async let weightedKeywords = WeightedKeyword.query(
                on: database, keywords: packageResult.repository.keywords
            )
            async let historyRecord = Self.History.query(on: database,
                                                    owner: owner,
                                                    repository: repository)
            async let productTypes = Self.ProductCount.query(on: database,
                                                        owner: owner,
                                                        repository: repository)
            async let buildInfo = Self.BuildInfo.query(on: database,
                                                  owner: owner,
                                                  repository: repository)

            guard
                let model = try await Self.Model(
                    result: packageResult,
                    history: historyRecord?.historyModel(),
                    productCounts: .init(
                        libraries: productTypes.filter(\.isLibrary).count,
                        executables: productTypes.filter(\.isExecutable).count,
                        plugins: productTypes.filter(\.isPlugin).count),
                    swiftVersionBuildInfo: buildInfo.swiftVersion,
                    platformBuildInfo: buildInfo.platform,
                    weightedKeywords: weightedKeywords
                ),
                let schema = PackageSchema(result: packageResult)
            else {
                throw Abort(.notFound)
            }

            return (model, schema)
        }

        enum History {
            struct Record: Codable, Equatable {
                var url: String
                var defaultBranch: String?
                var firstCommitDate: Date?
                var commitCount: Int
                var releaseCount: Int

                enum CodingKeys: String, CodingKey {
                    case url
                    case defaultBranch = "default_branch"
                    case firstCommitDate = "first_commit_date"
                    case commitCount = "commit_count"
                    case releaseCount = "release_count"
                }

                func historyModel() -> GetRoute.Model.History? {
                    guard let defaultBranch = defaultBranch,
                          let firstCommitDate = firstCommitDate else {
                        return nil
                    }
                    let cl = Link(
                        label: commitCount.labeled("commit"),
                        url: url.droppingGitExtension + "/commits/\(defaultBranch)")
                    let rl = Link(
                        label: releaseCount.labeled("release"),
                        url: url.droppingGitExtension + "/releases")
                    return .init(since: "\(inWords: Current.date().timeIntervalSince(firstCommitDate))",
                                 commitCount: cl,
                                 releaseCount: rl)
                }
            }

            static func query(on database: Database, owner: String, repository: String) async throws -> Record? {
                guard let db = database as? SQLDatabase else {
                    fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
                }
                // This query cannot expressed in Fluent, because it doesn't support
                // GROUP BY clauses.
                return try await db.raw(#"""
                    SELECT p.url, r.default_branch, r.first_commit_date, r.commit_count, count(v.reference) AS "release_count"
                    FROM packages p
                    JOIN repositories r ON r.package_id = p.id
                    LEFT JOIN versions v ON v.package_id = p.id
                        AND v.reference->'tag' IS NOT NULL
                        AND v.reference->'tag'->'semVer'->>'build' = ''
                        AND v.reference->'tag'->'semVer'->>'preRelease' = ''
                    WHERE r.owner ILIKE \#(bind: owner)
                    AND r.name ILIKE \#(bind: repository)
                    GROUP BY p.url, r.default_branch, r.first_commit_date, r.commit_count
                    """#)
                    .first(decoding: Record.self)
            }
        }

        enum ProductCount {
            static func query(on database: Database, owner: String, repository: String) async throws -> [ProductType] {
                try await Joined4<Package, Repository, Version, Product>
                    .query(on: database, owner: owner, repository: repository)
                    .field(Product.self, \.$type)
                    .all()
                    .compactMap(\.product.type)
            }
        }

        struct BuildInfo: Equatable {
            typealias ModelBuildInfo = GetRoute.Model.BuildInfo
            typealias NamedBuildResults = GetRoute.Model.NamedBuildResults
            typealias PlatformResults = GetRoute.Model.PlatformResults
            typealias SwiftVersionResults = GetRoute.Model.SwiftVersionResults

            var platform: ModelBuildInfo<PlatformResults>?
            var swiftVersion: ModelBuildInfo<SwiftVersionResults>?

            static func query(on database: Database, owner: String, repository: String) async throws -> Self {
                // FIXME: move up from PackageController.BuildsRoute into API.PackageController.BuildsRoute
                let builds = try await PackageController.BuildsRoute.BuildInfo.query(on: database,
                                                                   owner: owner,
                                                                   repository: repository)
                return Self.init(
                    platform: platformBuildInfo(builds: builds),
                    swiftVersion: swiftVersionBuildInfo(builds: builds)
                )
            }

            static func platformBuildInfo(
                builds: [PackageController.BuildsRoute.BuildInfo]
            ) -> ModelBuildInfo<PlatformResults>? {
                .init(stable: platformBuildResults(builds: builds,
                                                   kind: .release),
                      beta: platformBuildResults(builds: builds,
                                                 kind: .preRelease),
                      latest: platformBuildResults(builds: builds,
                                                   kind: .defaultBranch))
            }

            static func platformBuildResults(
                builds: [PackageController.BuildsRoute.BuildInfo],
                kind: Version.Kind
            ) -> NamedBuildResults<PlatformResults>? {
                let builds = builds.filter { $0.versionKind == kind}
                // builds of the same kind all originate from the same Version via a join,
                // so we can just pick the first one for the reference name
                guard let referenceName = builds.first?.reference.description else {
                    return nil
                }
                // For each reported platform pick appropriate build matches
                let ios = builds.filter { $0.platform.isCompatible(with: .ios) }
                let linux = builds.filter { $0.platform.isCompatible(with: .linux) }
                let macos = builds.filter { $0.platform.isCompatible(with: .macos) }
                let tvos = builds.filter { $0.platform.isCompatible(with: .tvos) }
                let watchos = builds.filter { $0.platform.isCompatible(with: .watchos) }
                // ... and report the status
                return
                    .init(referenceName: referenceName,
                          results: .init(iosStatus: ios.buildStatus,
                                         linuxStatus: linux.buildStatus,
                                         macosStatus: macos.buildStatus,
                                         tvosStatus: tvos.buildStatus,
                                         watchosStatus: watchos.buildStatus)
                    )
            }

            static func swiftVersionBuildInfo(
                builds: [PackageController.BuildsRoute.BuildInfo]
            ) -> ModelBuildInfo<SwiftVersionResults>? {
                .init(stable: swiftVersionBuildResults(builds: builds,
                                                       kind: .release),
                      beta: swiftVersionBuildResults(builds: builds,
                                                     kind: .preRelease),
                      latest: swiftVersionBuildResults(builds: builds,
                                                       kind: .defaultBranch))
            }

            static func swiftVersionBuildResults(
                builds: [PackageController.BuildsRoute.BuildInfo],
                kind: Version.Kind
            ) -> NamedBuildResults<SwiftVersionResults>? {
                let builds = builds.filter { $0.versionKind == kind}
                // builds of the same kind all originate from the same Version via a join,
                // so we can just pick the first one for the reference name
                guard let referenceName = builds.first?.reference.description else {
                    return nil
                }
                // For each reported swift version pick major/minor version matches
                let v5_5 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_5) }
                let v5_6 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_6) }
                let v5_7 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_7) }
                let v5_8 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_8) }
                // ... and report the status
                return
                    .init(referenceName: referenceName,
                          results: .init(status5_5: v5_5.buildStatus,
                                         status5_6: v5_6.buildStatus,
                                         status5_7: v5_7.buildStatus,
                                         status5_8: v5_8.buildStatus)
                    )
            }
        }

    }

}


extension API.PackageController.GetRoute {
    struct Model: Codable, Content, Equatable {
        var packageId: Package.Id
        var repositoryOwner: String
        var repositoryOwnerName: String
        var repositoryName: String
        var activity: Activity?
        var authors: AuthorMetadata?
        var keywords: [String]?
        var swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>?
        var platformBuildInfo: BuildInfo<PlatformResults>?
        var history: History?
        var license: License
        var licenseUrl: String?
        var productCounts: ProductCounts?
        var releases: ReleaseInfo
        var dependencies: [ResolvedDependency]?
        var stars: Int?
        var summary: String?
        var title: String
        var url: String
        var score: Int?
        var isArchived: Bool
        var hasBinaryTargets: Bool
        var homepageUrl: String?
        var hasDocumentation: Bool = false
        var weightedKeywords: [WeightedKeyword]
        var releaseReferences: [App.Version.Kind: App.Reference]

        internal init(packageId: Package.Id,
                      repositoryOwner: String,
                      repositoryOwnerName: String,
                      repositoryName: String,
                      activity: Activity? = nil,
                      authors: AuthorMetadata? = nil,
                      keywords: [String]? = nil,
                      swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>? = nil,
                      platformBuildInfo: BuildInfo<PlatformResults>? = nil,
                      history: History? = nil,
                      license: License,
                      licenseUrl: String? = nil,
                      productCounts: ProductCounts? = nil,
                      releases: ReleaseInfo,
                      dependencies: [ResolvedDependency]?,
                      stars: Int? = nil,
                      summary: String?,
                      title: String,
                      url: String,
                      score: Int? = nil,
                      isArchived: Bool,
                      hasBinaryTargets: Bool = false,
                      homepageUrl: String? = nil,
                      hasDocumentation: Bool = false,
                      weightedKeywords: [WeightedKeyword] = [],
                      defaultBranchReference: App.Reference,
                      releaseReference: App.Reference?,
                      preReleaseReference: App.Reference?) {
            self.packageId = packageId
            self.repositoryOwner = repositoryOwner
            self.repositoryOwnerName = repositoryOwnerName
            self.repositoryName = repositoryName
            self.activity = activity
            self.authors = authors
            self.keywords = keywords
            self.swiftVersionBuildInfo = swiftVersionBuildInfo
            self.platformBuildInfo = platformBuildInfo
            self.history = history
            self.license = license
            self.licenseUrl = licenseUrl
            self.productCounts = productCounts
            self.releases = releases
            self.dependencies = dependencies
            self.stars = stars
            self.summary = summary
            self.title = title
            self.url = url
            self.score = score
            self.isArchived = isArchived
            self.hasBinaryTargets = hasBinaryTargets
            self.homepageUrl = homepageUrl
            self.hasDocumentation = hasDocumentation
            self.weightedKeywords = weightedKeywords
            self.releaseReferences = {
                var refs = [App.Version.Kind.defaultBranch: defaultBranchReference]
                if let ref = releaseReference {
                    refs[.release] = ref
                }
                if let ref = preReleaseReference {
                    refs[.preRelease] = ref
                }
                return refs
            }()
        }

        init?(result: API.PackageController.PackageResult,
              history: History?,
              productCounts: ProductCounts,
              swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>?,
              platformBuildInfo: BuildInfo<PlatformResults>?,
              weightedKeywords: [WeightedKeyword] = []) {
            // we consider certain attributes as essential and return nil (raising .notFound)
            let repository = result.repository
            guard
                let repositoryOwner = repository.owner,
                let repositoryOwnerName = repository.ownerDisplayName,
                let repositoryName = repository.name,
                let packageId = result.package.id
            else { return nil }

            self.init(
                packageId: packageId,
                repositoryOwner: repositoryOwner,
                repositoryOwnerName: repositoryOwnerName,
                repositoryName: repositoryName,
                activity: result.activity(),
                authors: result.authors(),
                keywords: repository.keywords,
                swiftVersionBuildInfo: swiftVersionBuildInfo,
                platformBuildInfo: platformBuildInfo,
                history: history,
                license: repository.license,
                licenseUrl: repository.licenseUrl,
                productCounts: productCounts,
                releases: releaseInfo(
                    packageUrl: result.package.url,
                    defaultBranchVersion: result.defaultBranchVersion,
                    releaseVersion: result.releaseVersion,
                    preReleaseVersion: result.preReleaseVersion),
                dependencies: result.defaultBranchVersion.resolvedDependencies,
                stars: repository.stars,
                summary: repository.summary,
                title: result.defaultBranchVersion.packageName ?? repositoryName,
                url: result.package.url,
                score: result.package.score,
                isArchived: repository.isArchived,
                hasBinaryTargets: result.defaultBranchVersion.hasBinaryTargets,
                homepageUrl: repository.homepageUrl,
                hasDocumentation: result.hasDocumentation(),
                weightedKeywords: weightedKeywords,
                defaultBranchReference: result.defaultBranchVersion.reference,
                releaseReference: result.releaseVersion?.reference,
                preReleaseReference: result.preReleaseVersion?.reference
            )

        }
    }
}


extension API.PackageController.GetRoute.Model {
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

        init?(stable: NamedBuildResults<T>? = nil,
              beta: NamedBuildResults<T>? = nil,
              latest: NamedBuildResults<T>? = nil) {
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

        @available(*, deprecated)
        var longDisplayName: String {
            switch self {
                case .macos, .ios, .linux, .tvos, .watchos:
                    return displayName
            }
        }

        @available(*, deprecated)
        var note: String? {
            nil
        }
    }

    struct NamedBuildResults<T: Codable & Equatable>: Codable, Equatable {
        var referenceName: String
        var results: T
    }

    struct SwiftVersionResults: Codable, Equatable {
        var v5_5: BuildResult<SwiftVersion>
        var v5_6: BuildResult<SwiftVersion>
        var v5_7: BuildResult<SwiftVersion>
        var v5_8: BuildResult<SwiftVersion>

        init(status5_5: BuildStatus,
             status5_6: BuildStatus,
             status5_7: BuildStatus,
             status5_8: BuildStatus) {
            self.v5_5 = .init(parameter: .v5_5, status: status5_5)
            self.v5_6 = .init(parameter: .v5_6, status: status5_6)
            self.v5_7 = .init(parameter: .v5_7, status: status5_7)
            self.v5_8 = .init(parameter: .v5_8, status: status5_8)
        }

        var cells: [BuildResult<SwiftVersion>] { [v5_8, v5_7, v5_6, v5_5 ] }
    }

    struct PlatformResults: Codable, Equatable {
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

        var cells: [BuildResult<PlatformCompatibility>] { [ios, macos, watchos, tvos, linux] }
    }

    enum BuildStatus: String, Codable, Equatable {
        case compatible
        case incompatible
        case unknown
    }

    struct BuildResult<T: Codable & BuildResultParameter>: Codable, Equatable {
        var parameter: T
        var status: BuildStatus
    }

}


extension API.PackageController.PackageResult {

    func authors() -> AuthorMetadata? {
        if let spiManifest = defaultBranchVersion.spiManifest,
           let metadata = spiManifest.metadata,
           let authors = metadata.authors {
            return AuthorMetadata.fromSPIManifest(authors)
        } else if let authors = repository.authors {
            return AuthorMetadata.fromGitRepository(authors)
        } else {
            return nil
        }
    }

    func activity() -> API.PackageController.GetRoute.Model.Activity? {
        guard repository.lastPullRequestClosedAt != nil else { return nil }

        let openIssues = Link(label: repository.openIssues.labeled("open issue"),
                              url: package.url.droppingGitExtension + "/issues")
        let openPRs = Link(label: repository.openPullRequests.labeled("open pull request"),
                           url: package.url.droppingGitExtension + "/pulls")
        let lastIssueClosed = repository.lastIssueClosedAt.map { "\(date: $0, relativeTo: Current.date())" }
        let lastPRClosed = repository.lastPullRequestClosedAt.map { "\(date: $0, relativeTo: Current.date())" }
        return .init(openIssuesCount: repository.openIssues,
                     openIssues: openIssues,
                     openPullRequests: openPRs,
                     lastIssueClosedAt: lastIssueClosed,
                     lastPullRequestClosedAt: lastPRClosed)
    }

}


extension API.PackageController.GetRoute {
    static func releaseInfo(packageUrl: String,
                            defaultBranchVersion: DefaultVersion?,
                            releaseVersion: ReleaseVersion?,
                            preReleaseVersion: PreReleaseVersion?) -> Self.Model.ReleaseInfo {
        let links = [releaseVersion?.model, preReleaseVersion?.model, defaultBranchVersion?.model]
            .map { version -> DatedLink? in
                guard let version = version else { return nil }
                return makeDatedLink(packageUrl: packageUrl,
                                     version: version,
                                     keyPath: \.commitDate)
            }
        return .init(stable: links[0],
                     beta: links[1],
                     latest: links[2])
    }
}


extension API.PackageController.GetRoute {

    struct PackageSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case identifier, name, description, license, version,
                 codeRepository, url, datePublished, dateModified,
                 sourceOrganization, programmingLanguage, keywords
        }

        var context: String = "https://schema.org"
        var type: String = "SoftwareSourceCode"

        let identifier: String
        let name: String
        let description: String?
        let license: String?
        let version: String?
        let codeRepository: String
        let url: String
        let datePublished: Date?
        let dateModified: Date?
        let sourceOrganization: OrganisationSchema
        let programmingLanguage: ComputerLanguageSchema
        let keywords: [String]

        init(
            repositoryOwner: String,
            repositoryName: String,
            organisationName: String?,
            summary: String?,
            licenseUrl: String?,
            version: String?,
            repositoryUrl: String,
            datePublished: Date?,
            dateModified: Date?,
            keywords: [String]
        ) {
            self.identifier = "\(repositoryOwner)/\(repositoryName)"
            self.name = repositoryName
            self.description = summary
            self.license = licenseUrl
            self.version = version
            self.codeRepository = repositoryUrl
            self.url = SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).absoluteURL()
            self.datePublished = datePublished
            self.dateModified = dateModified
            self.sourceOrganization = OrganisationSchema(legalName: organisationName ?? repositoryOwner)
            self.programmingLanguage = ComputerLanguageSchema(name: "Swift", url: "https://swift.org/")
            self.keywords = keywords
        }

        init?(result: PackageController.PackageResult) {
            let package = result.package
            let repository = result.repository
            guard
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name
            else {
                return nil
            }

            self.init(
                repositoryOwner: repositoryOwner,
                repositoryName: repositoryName,
                organisationName: repository.ownerName,
                summary: repository.summary,
                licenseUrl: repository.licenseUrl,
                version: API.PackageController.GetRoute.releaseInfo(
                    packageUrl: package.url,
                    defaultBranchVersion: result.defaultBranchVersion,
                    releaseVersion: result.releaseVersion,
                    preReleaseVersion: result.preReleaseVersion).stable?.link.label,
                repositoryUrl: package.url.droppingGitExtension,
                datePublished: repository.firstCommitDate,
                dateModified: repository.lastActivityAt,
                keywords: repository.keywords
            )
        }

        var publicationDates: (datePublished: Date, dateModified: Date)? {
            guard let datePublished = datePublished, let dateModified = dateModified
            else { return nil }
            return (datePublished, dateModified)
        }
    }

    struct OrganisationSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case legalName
        }

        var context: String = "https://schema.org"
        var type: String = "Organization"

        let legalName: String

        init(legalName: String) {
            self.legalName = legalName
        }
    }

    struct ComputerLanguageSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case name, url
        }

        var context: String = "https://schema.org"
        var type: String = "ComputerLanguage"

        let name: String
        let url: String

        init(name: String, url: String) {
            self.name = name
            self.url = url
        }
    }

}
