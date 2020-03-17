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
  static func findByUrl(on connection: DatabaseConnectable, url: URL) -> Package
  {
    return Package.query(on: connection).filter(\.url).all()
  }
}

extension Package: PostgreSQLUUIDModel { }
extension Package: Migration { }
extension Package: Content { }
extension Package: Parameter { }
