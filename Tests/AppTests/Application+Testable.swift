import Vapor
import FluentPostgreSQL
import App

extension Application
{
  static func testable(environmentArguments: [String]? = nil) throws -> Application
  {
    var config = Config.default()
    var services = Services.default()
    var environment = Environment.testing

    // Does the testing environment have any custom environment arguments?
    if let environmentArguments = environmentArguments {
      environment.arguments = environmentArguments
    }

    try App.configure(&config, &environment, &services)

    // Configure a fake network client and keep a reference to it
    let basicContainer = BasicContainer(config: config, environment: environment, services: services, on: <#T##Worker#>)
    let fakeClient = FakeClient(container: BasicContainer)

    services.register(Client.self) { container -> FakeClient in
      return fakeClient
    }
    config.prefer(FakeClient.self, for: Client.self)

    let app = try Application(config: config, environment: environment, services: services)
    try App.boot(app)
    return app
  }

  static func reset() throws
  {
    let revertEnvironment = ["vapor", "revert", "--all", "-y"]
    try Application.testable(environmentArguments: revertEnvironment)
      .asyncRun()
      .wait()

    let migrateEnvironment = ["vapor", "migrate", "-y"]
    try Application.testable(environmentArguments: migrateEnvironment)
      .asyncRun()
      .wait()
  }

  static var fakeClient: FakeClient? {
    get {
      return objc_getAssociatedObject(self, &AssociatedObjectKeys.fakeClientKey) as? FakeClient
    }
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

  private struct AssociatedObjectKeys
  {
    static var fakeClientKey = "fakeClient"
  }
}

struct EmptyContent: Content { }
