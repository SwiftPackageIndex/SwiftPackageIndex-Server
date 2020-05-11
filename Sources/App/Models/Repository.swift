import Fluent
import Vapor


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

    @OptionalParent(key: "forked_from_id")  // TODO: remove or implement
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


extension Repository {
    static func defaultBranch(on db: Database, for package: Package) -> EventLoopFuture<String?> {
        do {
            return try Repository.query(on: db)
                .filter(\.$package.$id == package.requireID())
                .first()
                .map { $0?.defaultBranch }
        } catch {
            return db.eventLoop.makeSucceededFuture(nil)
        }
    }
}
