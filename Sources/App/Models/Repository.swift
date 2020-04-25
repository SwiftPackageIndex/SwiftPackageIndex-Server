import Fluent
import Vapor

final class Repository: Model, Content {
    static let schema = "repositories"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Parent(key: "package_id")
    var package: Package

    init() { }

    init(id: UUID? = nil, package: Package) throws {
        self.id = id
        self.$package.id = try package.requireID()
    }
}
