// swiftlint:disable force_try

import App
import Vapor

final class FakeClient: Client, Service {
  var container: Container
  private var clientResponses: [String: FakeClientResponse] = [:]

  init(container: Container) {
    self.container = container
  }

  func send(_ request: Request) -> EventLoopFuture<Response> {
    guard let response = clientResponses[request.http.urlString] else {
      return request.future(error: VaporError(identifier: "FakeClient", reason: "Unexpected URL"))
    }

    return createResponse(with: response, on: request)
  }

  private func createResponse(with clientResponse: FakeClientResponse, on req: Request) -> Future<Response> {
    if clientResponse.failRequest {
      return req.future(error: VaporError(identifier: "FakeClient", reason: "Client response was requested to fail"))
    }

    var response = HTTPResponse(status: clientResponse.responseStatus, body: clientResponse.responseBody)
    response.headers.add(name: .contentType, value: "application/json; charset=utf-8")
    let wrappedResponse = req.response(http: response)
    return req.future(wrappedResponse)
  }

//  static func response<T: Content>(status: HTTPStatus, for req: Request, data: T) -> EventLoopFuture<Response> {
//    var response = HTTPResponse(status: status)
//    response.headers.add(name: .contentType, value: "application/json; charset=utf-8")
//    let wrappedResponse = req.response(http: response)
//    try? wrappedResponse.content.encode(data)
//    return req.future(wrappedResponse)
//  }

  func registerClientResponse<T>(for urlString: String, failRequest: Bool = false, status: HTTPStatus = .ok, content: T) where T: Encodable {
    let encoder = JSONEncoder()
    let data = try! encoder.encode(content)
    guard let responseBody = String(data: data, encoding: .utf8)
      else { preconditionFailure("Failed to encode JSON response body") }
    clientResponses[urlString] = FakeClientResponse(responseStatus: status, responseBody: responseBody)
  }
}

struct FakeClientResponse {
  let failRequest: Bool
  let responseStatus: HTTPStatus
  let responseBody: String

  init(failRequest: Bool = false, responseStatus: HTTPStatus = .ok, responseBody: String = "{}") {
    self.failRequest = failRequest
    self.responseStatus = responseStatus
    self.responseBody = responseBody
  }
}
