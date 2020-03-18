import Vapor
import Fluent
import FluentPostgreSQL

final class Package: Codable
{
  static let entity = "packages"
  
  var id: UUID?
  private var urlString: String

  init(id: UUID? = nil, url: URL)
  {
    self.id = id
    self.urlString = url.absoluteString
  }

  var url: URL
  {
    get {
      guard let url = URL(string: urlString)
        else { preconditionFailure("Expected a valid URL in urlString") }
      return url
    }
    set {
      urlString = newValue.absoluteString
    }
  }
}

extension Package
{
  static func findByUrl(on connection: DatabaseConnectable, url: URL) -> Future<Package>
  {
    return Package.query(on: connection)
      .filter(\.urlString == url.absoluteString)
      .first()
      .unwrap(or: PackageError.recordNotFound)
  }
}

extension Package: PostgreSQLMigration
{
  static func prepare(on connection: PostgreSQLConnection) -> Future<Void>
  {
    return Database.create(Package.self, on: connection) { builder in
      try addProperties(to: builder)

      builder.unique(on: \.urlString)
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
