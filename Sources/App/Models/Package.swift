import Fluent
import Vapor

final class Package: Model, Content {
    static let schema = "packages"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "url")
    var url: String

    init() { }

    init(id: UUID? = nil, url: URL) {
        self.id = id
        self.url = url.absoluteString
    }
}
