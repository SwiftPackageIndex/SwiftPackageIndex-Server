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
        var swiftVersionBuildInfo: BuildInfo<SwiftVersionResults>?
        var platformCompatibility: [Model.PlatformCompatibility]?
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
        var documentationTarget: DocumentationTarget? = nil
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
                      documentationTarget: DocumentationTarget? = nil,
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
            self.swiftVersionCompatibility = swiftVersionBuildInfo?.compatibility
            self.swiftVersionBuildInfo = swiftVersionBuildInfo
            self.platformCompatibility = platformBuildInfo?.compatibility
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
            self.documentationTarget = documentationTarget
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
                documentationTarget: result.canonicalDocumentationTarget(),
                weightedKeywords: weightedKeywords,
                defaultBranchReference: result.defaultBranchVersion.reference,
                releaseReference: result.releaseVersion?.reference,
                preReleaseReference: result.preReleaseVersion?.reference
            )

        }
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

    struct ProductCounts: Codable, Equatable {
        var libraries: Int
        var executables: Int
        var plugins: Int
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

    enum PlatformCompatibility: String, Codable, Comparable {
        case iOS
        case linux
        case macOS
        case tvOS
        case watchos

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    struct NamedBuildResults<T: Codable & Equatable>: Codable, Equatable {
        var referenceName: String
        var results: T
    }

    struct SwiftVersionResults: Codable, Equatable {
        var v5_6: BuildResult<SwiftVersion>
        var v5_7: BuildResult<SwiftVersion>
        var v5_8: BuildResult<SwiftVersion>
        var v5_9: BuildResult<SwiftVersion>

        init(status5_6: BuildStatus,
             status5_7: BuildStatus,
             status5_8: BuildStatus,
             status5_9: BuildStatus) {
            self.v5_6 = .init(parameter: .v5_6, status: status5_6)
            self.v5_7 = .init(parameter: .v5_7, status: status5_7)
            self.v5_8 = .init(parameter: .v5_8, status: status5_8)
            self.v5_9 = .init(parameter: .v5_9, status: status5_9)
        }

        var all: [BuildResult<SwiftVersion>] { [v5_9, v5_8, v5_7, v5_6] }
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
            self.ios = .init(parameter: .iOS, status: iosStatus)
            self.linux = .init(parameter: .linux, status: linuxStatus)
            self.macos = .init(parameter: .macOS, status: macosStatus)
            self.tvos = .init(parameter: .tvOS, status: tvosStatus)
            self.watchos = .init(parameter: .watchos, status: watchosStatus)
        }

        var all: [BuildResult<PlatformCompatibility>] { [ios, macos, watchos, tvos, linux] }
    }

    enum BuildStatus: String, Codable, Equatable {
        case compatible
        case incompatible
        case unknown
    }

    struct BuildResult<T: Codable & Equatable>: Codable, Equatable {
        var parameter: T
        var status: BuildStatus
    }

}


extension API.PackageController.GetRoute.Model.BuildInfo where T == API.PackageController.GetRoute.Model.SwiftVersionResults {
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


extension API.PackageController.GetRoute.Model.BuildInfo where T == API.PackageController.GetRoute.Model.PlatformResults {
    var compatibility: [API.PackageController.GetRoute.Model.PlatformCompatibility] {
        var result = Set<API.PackageController.GetRoute.Model.PlatformCompatibility>()
        for v in [beta, stable, latest].compacted() {
            for r in v.results.all where r.status == .compatible {
                result.insert(r.parameter)
            }
        }
        return result.sorted()
    }
}
