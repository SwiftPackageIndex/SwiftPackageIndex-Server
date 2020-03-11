import Vapor
import FluentPostgreSQL
import App

extension Application
{
  static func testable(envArgs: [String]? = nil) throws -> Application
  {
    var config = Config.default()
    var services = Services.default()
    var env = Environment.testing

    if let environmentArgs = envArgs {
      env.arguments = environmentArgs
    }

    try App.configure(&config, &env, &services)
    let app = try Application(config: config, environment: env,services: services)

    try App.boot(app)
    return app
  }

  static func reset() throws
  {
    let revertEnvironment = ["vapor", "revert", "--all", "-y"]
    try Application.testable(envArgs: revertEnvironment).asyncRun().wait()
    let migrateEnvironment = ["vapor", "migrate", "-y"]
    try Application.testable(envArgs: migrateEnvironment).asyncRun().wait()
  }

  func sendRequest<T>(to path: String, method: HTTPMethod, headers: HTTPHeaders = .init(), body: T? = nil) throws -> Response where T: Content
  {
    let responder = try self.make(Responder.self)
    let request = HTTPRequest(method: method, url: URL(string: path)!, headers: headers)
    let wrappedRequest = Request(http: request, using: self)
    if let body = body {
      try wrappedRequest.content.encode(body)
    }
    return try responder.respond(to: wrappedRequest).wait()
  }

  func sendRequest(to path: String, method: HTTPMethod, headers: HTTPHeaders = .init()) throws -> Response
  {
    let emptyContent: EmptyContent? = nil
    return try sendRequest(to: path, method: method, headers: headers, body: emptyContent)
  }

  func sendRequest<T>(to path: String, method: HTTPMethod, headers: HTTPHeaders, data: T) throws where T: Content
  {
    _ = try self.sendRequest(to: path, method: method, headers: headers, body: data)
  }

  func getResponse<C, T>(to path: String, method: HTTPMethod = .GET, headers: HTTPHeaders = .init(), data: C? = nil, decodeTo type: T.Type) throws -> T where C: Content, T: Decodable
  {
    let response = try self.sendRequest(to: path, method: method, headers: headers, body: data)
    return try response.content.decode(type).wait()
  }

  func getResponse<T>(to path: String, method: HTTPMethod = .GET, headers: HTTPHeaders = .init(), decodeTo type: T.Type) throws -> T where T: Decodable
  {
    let emptyContent: EmptyContent? = nil
    return try self.getResponse(to: path, method: method, headers: headers, data: emptyContent, decodeTo: type)
  }
}

struct EmptyContent: Content { }
