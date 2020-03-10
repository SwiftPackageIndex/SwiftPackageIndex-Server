import Vapor
import FluentPostgreSQL

final class Todo: PostgreSQLUUIDModel {
  var id: UUID?
  var title: String

  init(id: UUID? = nil, title: String) {
    self.id = id
    self.title = title
  }
}

extension Todo: Migration { }
extension Todo: Content { }
extension Todo: Parameter { }
