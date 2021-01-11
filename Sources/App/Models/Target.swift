import Fluent
import Vapor


final class Target: Model, Content {
    static let schema = "targets"

    typealias Id = UUID

    // managed fields

    @ID(key: .id)
    var id: Id?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // reference fields

    @Parent(key: "version_id")
    var version: Version

    // data fields

    @Field(key: "name")
    var name: String

    // initializers

    init() { }

    init(id: UUID? = nil,
         version: Version,
         name: String) throws {
        self.id = id
        self.$version.id = try version.requireID()
        self.name = name
    }
}
