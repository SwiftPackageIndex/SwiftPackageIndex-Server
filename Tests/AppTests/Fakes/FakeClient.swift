import Vapor
import App

final class FakeClient: Client, Service
{
  var container: Container
  let clientResponses: [String: FakeClientResponse] = [:]

  init(container: Container)
  {
    self.container = container
  }

  func send(_ req: Request) -> EventLoopFuture<Response>
  {
    print("REQUESTING \(req.http.urlString)")

    guard let response = clientResponses[req.http.urlString] else {
      return req.future(error: VaporError(identifier: "FakeClient", reason: "Unexpected URL"))
    }

    return createResponse(with: response, on: req)
  }

  private func createResponse(with clientResponse: FakeClientResponse, on req: Request) -> Future<Response>
  {
    if clientResponse.failRequest {
      return req.future(error: VaporError(identifier: "FakeClient", reason: "Client failed"))
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
}

struct FakeClientResponse
{
  let failRequest: Bool
  let responseStatus: HTTPStatus
  let responseBody: String

  init(failRequest: Bool = false, responseStatus: HTTPStatus = .ok, responseBody: String = "{}")
  {
    self.failRequest = failRequest
    self.responseStatus = responseStatus
    self.responseBody = responseBody
  }
}
