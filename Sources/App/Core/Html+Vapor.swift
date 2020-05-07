import Vapor

extension HTML.Node: ResponseEncodable {
    func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let res = Response(status: .ok, body: .init(string: HTML.render(self)))
        res.headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
        return request.eventLoop.makeSucceededFuture(res)
    }
}
