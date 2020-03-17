import Vapor
import Fluent
import FluentPostgreSQL

final class Package
{
  static let entity = "packages"
  
  var id: UUID?
  var url: URL?

  init(id: UUID? = nil, url: URL? = nil)
  {
    self.id = id
    self.url = url
  }

  init(id: UUID? = nil, urlString: String)
  {
    self.id = id
    self.url = URL(string: urlString)
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

extension Package: Migration
{
  static func prepare(on connection: PostgreSQLConnection) -> Future<Void>
  {
    return Database.create(self, on: connection) { builder in
      try addProperties(to: builder)

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
