import Fluent
import Vapor


final class Product: Model, Content {
    static let schema = "products"
    
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
    
    @Field(key: "type")
    var type: `Type`
    
    @Field(key: "name")
    var name: String

    @Field(key: "targets")
    var targets: [String]
    
    init() {}
    
    init(id: Id? = nil,
         version: Version,
         type: `Type`,
         name: String,
         targets: [String] = []) throws {
        self.id = id
        self.$version.id = try version.requireID()
        self.type = type
        self.name = name
        self.targets = targets
    }
}


extension Product {
    enum `Type`: String, Codable {
        case executable
        case library

        init(manifestProductType: Manifest.Product.`Type`) {
            switch manifestProductType {
                case .executable:
                    self = .executable
                case .library:
                    self = .library
            }
        }
    }
    
    var isLibrary: Bool { return type == .library }
    var isExecutable: Bool { return type == .executable }
}


extension Product: Equatable {
    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }
}
