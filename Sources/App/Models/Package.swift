import Vapor
import Fluent
import FluentPostgreSQL

final class Package: Codable
{
  static let entity = "packages"
  
  var id: UUID?
  var url: URL

  init(id: UUID? = nil, url: URL)
  {
    self.id = id
    self.url = url
  }

  init(from decoder: Decoder) throws
  {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try values.decode(UUID.self, forKey: .id)

    guard let url = URL(string: try values.decode(String.self, forKey: .url))
      else { preconditionFailure("Expected a valid URL") }
    self.url = url
  }

  func encode(to encoder: Encoder) throws
  {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(url.absoluteString, forKey: .url)
  }

  enum CodingKeys: String, CodingKey
  {
    case id
    case url
  }
}

extension Package
{
  static func findByUrl(on connection: DatabaseConnectable, url: URL) -> Future<Package>
  {
    return Package.query(on: connection)
      .filter(\.url == url)
      .first()
      .unwrap(or: PackageError.recordNotFound)
  }
}

extension Package: PostgreSQLMigration
{
  static func prepare(on connection: PostgreSQLConnection) -> Future<Void>
  {
    return Database.create(Package.self, on: connection) { builder in
      builder.field(for: \.id, isIdentifier: true)
      builder.field(for: \.url, type: .text)

      builder.unique(on: \.url)
    }
  }
}

extension Package: PostgreSQLUUIDModel { }
extension Package: Content { }
extension Package: Parameter { }

enum PackageError: Error
{
  case recordNotFound
}
