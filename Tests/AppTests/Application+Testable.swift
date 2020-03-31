import Vapor
import FluentPostgreSQL
import App

var singletonFakeClient: FakeClient!

extension Application {
  static func testable(environmentArguments: [String]? = nil) throws -> Application {
    var config = Config.default()
    var services = Services.default()
    var environment = Environment.testing

    // Does the testing environment have any custom environment arguments?
    if let environmentArguments = environmentArguments {
      environment.arguments = environmentArguments
    }

    try App.configure(&config, &environment, &services)

    // Register a fake networking client. I know this code is nasty, but using a singleton like this is the
    // cleanest way I could find to be able to get back the same instance of the client inside a test case.
    // To get back the same client inside a test case, do `let fakeClient = try app.make(FakeClient.self)`
    services.register(Client.self) { container -> FakeClient in
      if let fakeClient = singletonFakeClient {
        return fakeClient
      } else {
        singletonFakeClient = FakeClient(container: container)
        return singletonFakeClient
      }
    }
    config.prefer(FakeClient.self, for: Client.self)

    let app = try Application(config: config, environment: environment, services: services)
    try App.boot(app)
    return app
  }

  static func reset() throws {
    let revertEnvironment = ["vapor", "revert", "--all", "-y"]
    try Application.testable(environmentArguments: revertEnvironment)
      .asyncRun()
      .wait()

    let migrateEnvironment = ["vapor", "migrate", "-y"]
    try Application.testable(environmentArguments: migrateEnvironment)
      .asyncRun()
      .wait()
  }

  func sendRequest<T>(to path: String, method: HTTPMethod, headers: HTTPHeaders = .init(), body: T? = nil) throws -> Response where T: Content {
    let responder = try self.make(Responder.self)
    let request = HTTPRequest(method: method, url: URL(string: path)!, headers: headers)
    let wrappedRequest = Request(http: request, using: self)
    if let body = body {
      try wrappedRequest.content.encode(body)
    }
    return try responder.respond(to: wrappedRequest).wait()
  }

  func sendRequest(to path: String, method: HTTPMethod, headers: HTTPHeaders = .init()) throws -> Response {
    let emptyContent: EmptyContent? = nil
    return try sendRequest(to: path, method: method, headers: headers, body: emptyContent)
  }

  func sendRequest<T>(to path: String, method: HTTPMethod, headers: HTTPHeaders, data: T) throws where T: Content {
    _ = try self.sendRequest(to: path, method: method, headers: headers, body: data)
  }

  func getResponse<C, T>(to path: String, method: HTTPMethod = .GET, headers: HTTPHeaders = .init(), data: C? = nil, decodeTo type: T.Type) throws -> T where C: Content, T: Decodable {
    let response = try self.sendRequest(to: path, method: method, headers: headers, body: data)
    return try response.content.decode(type).wait()
  }

  func getResponse<T>(to path: String, method: HTTPMethod = .GET, headers: HTTPHeaders = .init(), decodeTo type: T.Type) throws -> T where T: Decodable {
    let emptyContent: EmptyContent? = nil
    return try self.getResponse(to: path, method: method, headers: headers, data: emptyContent, decodeTo: type)
  }
}

struct EmptyContent: Content { }
