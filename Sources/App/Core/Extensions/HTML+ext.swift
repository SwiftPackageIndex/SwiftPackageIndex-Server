import Plot
import Vapor


extension HTML: ResponseEncodable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let res = Response(status: .ok, body: .init(string: self.render()))
        res.headers.add(name: "Content-Type", value: "text/html; charset=utf-8")
        return request.eventLoop.makeSucceededFuture(res)
    }
}
