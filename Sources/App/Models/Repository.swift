import Fluent
import Vapor


// TODO: sas 2020-04-26: discuss whether we want to inline Repository with Package rather than
// maintain a 1-1 link. Or are expecting that not to be a 1-1 link at some point?
final class Repository: Model, Content {
    static let schema = "repositories"

    typealias Id = UUID

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Parent(key: "package_id")
    var package: Package

    @Field(key: "description")
    var description: String?

    @Field(key: "default_branch")
    var defaultBranch: String?

    @Field(key: "license")
    var license: String?

    @Field(key: "stars")
    var stars: Int?

    @Field(key: "forks")
    var forks: Int?

    @OptionalParent(key: "forked_from_id")
    var forkedFrom: Repository?

    init() { }

    init(id: Id? = nil,
         package: Package,
         description: String? = nil,
         defaultBranch: String? = nil,
         license: String? = nil,
         stars: Int? = nil,
         forks: Int? = nil,
         forkedFrom: Repository? = nil) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.description = description
        self.defaultBranch = defaultBranch
        self.license = license
        self.stars = stars
        self.forks = forks
        if let forkId = forkedFrom?.id {
            self.$forkedFrom.id = forkId
        }
    }

    init(id: Id? = nil, package: Package, metadata: Github.Metadata) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.description = metadata.description
        self.defaultBranch = metadata.defaultBranch
        self.license = metadata.license?.key
        self.stars = metadata.stargazersCount
        self.forks = metadata.forksCount
        // if let parent = metadata.parent {
        //   TODO: find parent repo and assing it
        //            self.$forkedFrom.id = forkId
        // }
    }
}


extension Repository: Equatable {
    static func == (lhs: Repository, rhs: Repository) -> Bool {
        lhs.id == rhs.id
    }
}
