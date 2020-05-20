import Fluent
import Vapor


final class Repository: Model, Content {
    static let schema = "repositories"

    typealias Id = UUID

    // record metadata

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // data fields

    @Field(key: "default_branch")
    var defaultBranch: String?

    @Field(key: "forks")
    var forks: Int?
    
    @Field(key: "license")
    var license: License

    @Field(key: "name")
    var name: String?

    @Field(key: "owner")
    var owner: String?

    @Field(key: "stars")
    var stars: Int?

    @Field(key: "summary")
    var summary: String?

    // relationships

    @Parent(key: "package_id")
    var package: Package

    @OptionalParent(key: "forked_from_id")  // TODO: remove or implement
    var forkedFrom: Repository?

    // initializers

    init() { }

    init(id: Id? = nil,
         package: Package,
         summary: String? = nil,
         defaultBranch: String? = nil,
         license: License = .none,
         name: String? = nil,
         owner: String? = nil,
         stars: Int? = nil,
         forks: Int? = nil,
         forkedFrom: Repository? = nil) throws {
        self.id = id
        self.$package.id = try package.requireID()
        self.summary = summary
        self.defaultBranch = defaultBranch
        self.license = license
        self.name = name
        self.owner = owner
        self.stars = stars
        self.forks = forks
        if let forkId = forkedFrom?.id {
            self.$forkedFrom.id = forkId
        }
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
