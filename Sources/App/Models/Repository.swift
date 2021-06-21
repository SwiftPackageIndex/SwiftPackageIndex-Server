import Fluent
import Vapor


final class Repository: Model, Content {
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
    
    @OptionalParent(key: "forked_from_id")  // TODO: remove or implement
    var forkedFrom: Repository?
    
    @Parent(key: "package_id")
    var package: Package
    
    // data fields
    
    @Field(key: "authors")
    var authors: [Author]
    
    @Field(key: "commit_count")
    var commitCount: Int?
    
    @Field(key: "default_branch")
    var defaultBranch: String?
    
    @Field(key: "first_commit_date")
    var firstCommitDate: Date?
    
    @Field(key: "forks")
    var forks: Int?

    @Field(key: "is_archived")
    var isArchived: Bool?

    @Field(key: "is_in_organization")
    var isInOrganization: Bool?

    @Field(key: "keywords")
    var keywords: [String]

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
    var openIssues: Int?

    @Field(key: "open_pull_requests")
    var openPullRequests: Int?

    @Field(key: "owner")
    var owner: String?

    @Field(key: "owner_name")
    var ownerName: String?

    @Field(key: "owner_avatar_url")
    var ownerAvatarUrl: String?

    @Field(key: "readme_url")
    var readmeUrl: String?

    @Field(key: "readme_html_url")
    var readmeHtmlUrl: String?

    @Field(key: "releases")
    var releases: [Release]

    @Field(key: "stars")
    var stars: Int?

    @Field(key: "summary")
    var summary: String?

    // initializers
    
    init() { }
    
    init(id: Id? = nil,
         package: Package,
         authors: [Author] = [],
         commitCount: Int? = nil,
         defaultBranch: String? = nil,
         firstCommitDate: Date? = nil,
         forks: Int? = nil,
         forkedFrom: Repository? = nil,
         isArchived: Bool? = nil,
         isInOrganization: Bool? = nil,
         keywords: [String] = [],
         lastCommitDate: Date? = nil,
         lastIssueClosedAt: Date? = nil,
         lastPullRequestClosedAt: Date? = nil,
         license: License = .none,
         licenseUrl: String? = nil,
         name: String? = nil,
         openIssues: Int? = nil,
         openPullRequests: Int? = nil,
         owner: String? = nil,
         ownerName: String? = nil,
         ownerAvatarUrl: String? = nil,
         readmeUrl: String? = nil,
         readmeHtmlUrl: String? = nil,
         releases: [Release] = [],
         stars: Int? = nil,
         summary: String? = nil
    ) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.authors = authors
        self.summary = summary
        self.commitCount = commitCount
        self.firstCommitDate = firstCommitDate
        self.forks = forks
        if let forkId = forkedFrom?.id {
            self.$forkedFrom.id = forkId
        }
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
        self.readmeUrl = readmeUrl
        self.readmeHtmlUrl = readmeHtmlUrl
        self.releases = releases
        self.stars = stars
    }
    
    init(packageId: Package.Id) {
        self.$package.id = packageId
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
