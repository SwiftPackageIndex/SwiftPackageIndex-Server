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
    var type: ProductType
    
    @Field(key: "name")
    var name: String

    @Field(key: "targets")
    var targets: [String]
    
    init() {}
    
    init(id: Id? = nil,
         version: Version,
         type: ProductType,
         name: String,
         targets: [String] = []) throws {
        self.id = id
        self.$version.id = try version.requireID()
        self.type = type
        self.name = name
        self.targets = targets
    }
}


enum ProductType: Equatable {
    case executable
    case library(LibraryType)
    case test

    init(manifestProductType: Manifest.Product.`Type`) {
        switch manifestProductType {
            case .executable:
                self = .executable
            case .library:
                // FIXME: extend manifest parsing
                self = .library(.automatic)
        }
    }

    enum LibraryType: String, Codable {
        case automatic
        case `dynamic`
        case `static`
    }
}


extension Product {
    var isLibrary: Bool {
        switch type {
            case .library: return true
            case .executable, .test: return false
        }
    }
    var isExecutable: Bool {
        switch type {
            case .executable: return true
            case .library, .test: return false
        }
    }
}


extension Product: Equatable {
    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }
}



// https://github.com/apple/swift-evolution/blob/main/proposals/0295-codable-synthesis-for-enums-with-associated-values.md
@available(swift, deprecated: 5.5, message: "Remove when Codable synthesis for enums with associated values (SE-0295) ships")
extension ProductType: Codable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.allKeys.count == 1 else {
            throw DecodingError.typeMismatch(Self.self, .init(
                codingPath: container.codingPath,
                debugDescription: "Invalid number of keys found, expected one."
            ))
        }

        switch container.allKeys.first! {
            case .executable:
                self = .executable
            case .library:
                let nestedContainer = try container.nestedContainer(keyedBy: LibraryCodingKeys.self, forKey: .library)
                let type = try nestedContainer.decode(LibraryType.self, forKey: ._0)
                self = .library(type)
            case .test:
                self = .test
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .executable:
                try container.encode(Empty(), forKey: .executable)
            case let .library(type):
                var nestedContainer = container.nestedContainer(keyedBy: LibraryCodingKeys.self, forKey: .library)
                try nestedContainer.encode(type, forKey: ._0)
            case .test:
                try container.encode(Empty(), forKey: .test)
        }
    }

    struct Empty: Encodable {}

    enum CodingKeys: CodingKey {
        case executable
        case library
        case test
    }

    enum LibraryCodingKeys: CodingKey {
        case _0
    }

}
