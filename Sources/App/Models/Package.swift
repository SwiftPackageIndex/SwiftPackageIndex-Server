import Vapor
import FluentPostgreSQL

final class Package {
  var id: UUID?
  var url: URL

  init(id: UUID? = nil, url: URL) {
    self.id = id
    self.url = url
  }
}

extension Package: PostgreSQLUUIDModel { }
extension Package: Migration { }
extension Package: Content { }
extension Package: Parameter { }
