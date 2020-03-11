import Vapor
import FluentPostgreSQL

final class Package
{
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

extension Package: PostgreSQLUUIDModel { }
extension Package: Migration { }
extension Package: Content { }
extension Package: Parameter { }
