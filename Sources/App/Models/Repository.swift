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

import Fluent
import Vapor


final class Repository: @unchecked Sendable, Model, Content {
    static let schema = "repositories"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // reference fields

    @Parent(key: "package_id")
    var package: Package

    // data fields

    @Field(key: "authors")
    var authors: PackageAuthors?

    @Field(key: "commit_count")
    var commitCount: Int

    @Field(key: "default_branch")
    var defaultBranch: String?

    @Field(key: "first_commit_date")
    var firstCommitDate: Date?
    
    @Field(key: "forked_from")
    var forkedFrom: Fork?

    @Field(key: "forks")
    var forks: Int

    @Field(key: "funding_links")
    var fundingLinks: [FundingLink]

    @Field(key: "homepage_url")
    var homepageUrl: String?

    @Field(key: "is_archived")
    var isArchived: Bool

    @Field(key: "is_in_organization")
    var isInOrganization: Bool

    @Field(key: "keywords")
    var keywords: [String]

    @Field(key: "last_activity_at")
    var lastActivityAt: Date?

    @Field(key: "last_commit_date")
    var lastCommitDate: Date?

    @Field(key: "last_issue_closed_at")
    var lastIssueClosedAt: Date?

    @Field(key: "last_pull_request_closed_at")
    var lastPullRequestClosedAt: Date?

    @Field(key: "license")
    var license: License

    @Field(key: "license_url")
    var licenseUrl: String?

    @Field(key: "name")
    var name: String?

    @Field(key: "open_issues")
    var openIssues: Int

    @Field(key: "open_pull_requests")
    var openPullRequests: Int

    @Field(key: "owner")
    var owner: String?

    @Field(key: "owner_name")
    var ownerName: String?

    @Field(key: "owner_avatar_url")
    var ownerAvatarUrl: String?

    @Field(key: "readme_html_url")
    var readmeHtmlUrl: String?

    @Field(key: "releases")
    var releases: [Release]
    
    @Field(key: "s3_readme")
    var s3Readme: S3Readme?

    @Field(key: "stars")
    var stars: Int

    @Field(key: "summary")
    var summary: String?

    // initializers

    init() { }

    init(id: Id? = nil,
         package: Package,
         authors: PackageAuthors? = nil,
         commitCount: Int = 0,
         defaultBranch: String? = nil,
         firstCommitDate: Date? = nil,
         forks: Int = 0,
         fundingLinks: [FundingLink] = [],
         forkedFrom: Fork? = nil,
         homepageUrl: String? = nil,
         isArchived: Bool = false,
         isInOrganization: Bool = false,
         keywords: [String] = [],
         lastCommitDate: Date? = nil,
         lastIssueClosedAt: Date? = nil,
         lastPullRequestClosedAt: Date? = nil,
         license: License = .none,
         licenseUrl: String? = nil,
         name: String? = nil,
         openIssues: Int = 0,
         openPullRequests: Int = 0,
         owner: String? = nil,
         ownerName: String? = nil,
         ownerAvatarUrl: String? = nil,
         readmeHtmlUrl: String? = nil,
         releases: [Release] = [],
         s3Readme: S3Readme? = nil,
         stars: Int = 0,
         summary: String? = nil
    ) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.authors = authors
        self.summary = summary
        self.commitCount = commitCount
        self.firstCommitDate = firstCommitDate
        self.forks = forks
        self.forkedFrom = forkedFrom
        self.fundingLinks = fundingLinks
        self.homepageUrl = homepageUrl
        self.isArchived = isArchived
        self.isInOrganization = isInOrganization
        self.keywords = keywords
        self.lastCommitDate = lastCommitDate
        self.lastIssueClosedAt = lastIssueClosedAt
        self.lastPullRequestClosedAt = lastPullRequestClosedAt
        self.defaultBranch = defaultBranch
        self.license = license
        self.licenseUrl = licenseUrl
        self.name = name
        self.openIssues = openIssues
        self.openPullRequests = openPullRequests
        self.owner = owner
        self.ownerName = ownerName
        self.ownerAvatarUrl = ownerAvatarUrl
        self.readmeHtmlUrl = readmeHtmlUrl
        self.releases = releases
        self.s3Readme = s3Readme
        self.stars = stars
    }

    init(packageId: Package.Id) {
        self.$package.id = packageId
        self.authors = nil
        self.commitCount = 0
        self.defaultBranch = nil
        self.firstCommitDate = nil
        self.forks = 0
        self.fundingLinks = []
        self.homepageUrl = nil
        self.isArchived = false
        self.isInOrganization = false
        self.keywords = []
        self.lastCommitDate = nil
        self.lastIssueClosedAt = nil
        self.lastPullRequestClosedAt = nil
        self.license = .none
        self.licenseUrl = nil
        self.name = nil
        self.openIssues = 0
        self.openPullRequests = 0
        self.owner = nil
        self.ownerName = nil
        self.ownerAvatarUrl = nil
        self.readmeHtmlUrl = nil
        self.releases = []
        self.s3Readme = nil
        self.stars = 0
        self.summary = nil
    }

    static func findOrCreate(on database: Database, for package: Package) async throws -> Repository {
        let pkgId = try package.requireID()
        return try await Repository.query(on: database)
            .filter(\.$package.$id == pkgId)
            .first() ?? Repository(packageId: pkgId)
    }
}


extension Repository: Equatable {
    static func == (lhs: Repository, rhs: Repository) -> Bool {
        lhs.id == rhs.id
    }
}

extension Repository {
    var ownerDisplayName: String? {
        ownerName ?? owner
    }
}


enum S3Readme: Codable, Equatable {
    case cached(s3ObjectUrl: String, githubEtag: String)
    case error(String)

    var isCached: Bool {
        switch self {
            case .cached:
                return true
            case .error:
                return false
        }
    }

    var isError: Bool {
        switch self {
            case .cached:
                return false
            case .error:
                return true
        }
    }

    func needsUpdate(upstreamEtag: String) -> Bool {
        switch self {
            case let .cached(_, githubEtag: existingEtag):
                return existingEtag != upstreamEtag
            case .error:
                return true
        }
    }
}

enum Fork: Codable, Equatable {
    case parentId(Package.Id)
    case parentURL(String)
}
