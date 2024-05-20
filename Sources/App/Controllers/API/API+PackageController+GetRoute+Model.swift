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

import DependencyResolution
import PackageModel
import Vapor


extension API.PackageController.GetRoute {
    struct Model: Content, Equatable {
        var packageId: Package.Id
        var repositoryOwner: String
        var repositoryOwnerName: String
        var repositoryName: String
        var activity: Activity?
        var authors: AuthorMetadata?
        var keywords: [String]?
        var swiftVersionCompatibility: [SwiftVersion]?
        var swiftVersionBuildInfo: BuildInfo<CompatibilityMatrix.SwiftVersionCompatibility>?
        var platformCompatibility: [CompatibilityMatrix.Platform]?
        var platformBuildInfo: BuildInfo<CompatibilityMatrix.PlatformCompatibility>?
        var history: History?
        var license: License
        var licenseUrl: String?
        var products: [Product]?
        var releases: ReleaseInfo
        var dependencies: [ResolvedDependency]?
        var stars: Int?
        var summary: String?
        var title: String
        var targets: [Target]?
        var url: String
        var score: Int?
        var isArchived: Bool
        var hasBinaryTargets: Bool
        var homepageUrl: String?
        var currentDocumentationTarget: DocumentationTarget? = nil
        var weightedKeywords: [WeightedKeyword]
        var releaseReferences: [App.Version.Kind: App.Reference]
        var fundingLinks: [FundingLink]
        var swift6Readiness: Swift6Readiness?

        internal init(packageId: Package.Id,
                      repositoryOwner: String,
                      repositoryOwnerName: String,
                      repositoryName: String,
                      activity: Activity? = nil,
                      authors: AuthorMetadata? = nil,
                      keywords: [String]? = nil,
                      swiftVersionBuildInfo: BuildInfo<CompatibilityMatrix.SwiftVersionCompatibility>? = nil,
                      platformBuildInfo: BuildInfo<CompatibilityMatrix.PlatformCompatibility>? = nil,
                      history: History? = nil,
                      license: License,
                      licenseUrl: String? = nil,
                      products: [Product]? = nil,
                      releases: ReleaseInfo,
                      dependencies: [ResolvedDependency]?,
                      stars: Int? = nil,
                      summary: String?,
                      targets: [Target]? = nil,
                      title: String,
                      url: String,
                      score: Int? = nil,
                      isArchived: Bool,
                      hasBinaryTargets: Bool = false,
                      homepageUrl: String? = nil,
                      currentDocumentationTarget: DocumentationTarget? = nil,
                      weightedKeywords: [WeightedKeyword] = [],
                      defaultBranchReference: App.Reference,
                      releaseReference: App.Reference?,
                      preReleaseReference: App.Reference?,
                      fundingLinks: [FundingLink] = [],
                      swift6Readiness: Swift6Readiness?
            ) {
            self.packageId = packageId
            self.repositoryOwner = repositoryOwner
            self.repositoryOwnerName = repositoryOwnerName
            self.repositoryName = repositoryName
            self.activity = activity
            self.authors = authors
            self.keywords = keywords
            self.swiftVersionCompatibility = swiftVersionBuildInfo?.compatibility
            self.swiftVersionBuildInfo = swiftVersionBuildInfo
            self.platformCompatibility = platformBuildInfo?.compatibility
            self.platformBuildInfo = platformBuildInfo
            self.history = history
            self.license = license
            self.licenseUrl = licenseUrl
            self.products = products
            self.releases = releases
            self.dependencies = dependencies
            self.stars = stars
            self.summary = summary
            self.targets = targets
            self.title = title
            self.url = url
            self.score = score
            self.isArchived = isArchived
            self.hasBinaryTargets = hasBinaryTargets
            self.homepageUrl = homepageUrl
            self.currentDocumentationTarget = currentDocumentationTarget
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
            self.fundingLinks = fundingLinks
            self.swift6Readiness = swift6Readiness
        }

        init?(result: API.PackageController.PackageResult,
              history: History?,
              products: [Product],
              targets: [Target],
              swiftVersionBuildInfo: BuildInfo<CompatibilityMatrix.SwiftVersionCompatibility>?,
              platformBuildInfo: BuildInfo<CompatibilityMatrix.PlatformCompatibility>?,
              weightedKeywords: [WeightedKeyword] = [],
              swift6Readiness: Swift6Readiness?) {
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
                products: products,
                releases: releaseInfo(
                    packageUrl: result.package.url,
                    defaultBranchVersion: result.defaultBranchVersion,
                    releaseVersion: result.releaseVersion,
                    preReleaseVersion: result.preReleaseVersion),
                dependencies: result.defaultBranchVersion.resolvedDependencies,
                stars: repository.stars,
                summary: repository.summary,
                targets: targets,
                title: result.defaultBranchVersion.packageName ?? repositoryName,
                url: result.package.url,
                score: result.package.score,
                isArchived: repository.isArchived,
                hasBinaryTargets: result.defaultBranchVersion.hasBinaryTargets,
                homepageUrl: repository.homepageUrl,
                currentDocumentationTarget: result.currentDocumentationTarget(),
                weightedKeywords: weightedKeywords,
                defaultBranchReference: result.defaultBranchVersion.reference,
                releaseReference: result.releaseVersion?.reference,
                preReleaseReference: result.preReleaseVersion?.reference,
                fundingLinks: result.repository.fundingLinks,
                swift6Readiness: swift6Readiness
            )

        }
    }
}


extension API.PackageController.GetRoute.Model {
    var packageIdentity: String {
        PackageIdentity(urlString: url).description
    }
}


extension API.PackageController.GetRoute.Model {
    enum AuthorMetadata : Codable, Equatable {
        case fromSPIManifest(String)
        case fromGitRepository(PackageAuthors)
    }

    struct History: Codable, Equatable {
        var createdAt: Date
        var commitCount: Int
        var commitCountURL: String
        var releaseCount: Int
        var releaseCountURL: String
    }

    struct Activity: Codable, Equatable {
        var openIssuesCount: Int
        var openIssuesURL: String?
        var openPullRequestsCount: Int
        var openPullRequestsURL: String?
        var lastIssueClosedAt: Date?
        var lastPullRequestClosedAt: Date?
    }

    struct Product: Codable, Equatable {
        var name: String
        var type: ProductType

        init(name: String, type: ProductType) {
            self.name = name
            self.type = type
        }

        init?(name: String, productType: App.ProductType) {
            guard let type = ProductType(productType) else { return nil }
            self.name = name
            self.type = type
        }

        enum ProductType: Codable, Equatable {
            case library
            case executable
            case plugin
            
            init?(_ productType: App.ProductType) {
                switch productType {
                    case .executable:
                        self = .executable
                    case .library:
                        self = .library
                    case .plugin:
                        self = .plugin
                    case .test:
                        return nil
                }
            }
        }
    }

    struct Target: Codable, Equatable {
        var name: String
        var type: TargetType

        init(name: String, type: TargetType) {
            self.name = name
            self.type = type
        }

        init?(name: String, targetType: App.TargetType) {
            guard let type = TargetType(targetType) else { return nil }
            self.name = name
            self.type = type
        }

        enum TargetType: Codable, Equatable {
            case macro
            case test
            
            init?(_ productType: App.TargetType) {
                switch productType {
                case .macro:
                    self = .macro
                case .test:
                    self = .test
                default:
                    return nil
                }
            }
            
            var targetType: App.TargetType {
                switch self {
                case .macro:
                    return .macro
                case .test:
                    return .test
                }
            }
        }
    }

    struct ReleaseInfo: Codable, Equatable {
        var stable: DateLink?
        var beta: DateLink?
        var latest: DateLink?
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

    struct NamedBuildResults<T: Codable & Equatable>: Codable, Equatable {
        var referenceName: String
        var results: T
    }

    struct Swift6Readiness: Codable, Equatable {
        var errorCounts: [Build.Platform: Int?] = [:]

        enum DataRaceSafety {
            case safe
            case unsafe
            case unknown
        }

        var dataRaceSafety: DataRaceSafety {
            let results = errorCounts.values.compacted()
            if results.isEmpty {
                return .unknown
            } else {
                return results.first(where: { $0 == 0 }) != nil ? .safe : .unsafe
            }
        }
    }

}


extension API.PackageController.GetRoute.Model.BuildInfo<CompatibilityMatrix.SwiftVersionCompatibility> {
    var compatibility: [SwiftVersion] {
        var result = Set<SwiftVersion>()
        for v in [beta, stable, latest].compacted() {
            for r in v.results.all where r.status == .compatible {
                result.insert(r.parameter)
            }
        }
        return result.sorted()
    }
}


extension API.PackageController.GetRoute.Model.BuildInfo<CompatibilityMatrix.PlatformCompatibility> {
    var compatibility: [CompatibilityMatrix.Platform] {
        var result = Set<CompatibilityMatrix.Platform>()
        for v in [beta, stable, latest].compacted() {
            for r in v.results.all where r.status == .compatible {
                result.insert(r.parameter)
            }
        }
        return result.sorted()
    }
}
