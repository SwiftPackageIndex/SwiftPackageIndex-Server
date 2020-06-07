import Plot
import Vapor


extension RSS: ResponseEncodable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let res = Response(status: .ok, body: .init(string: self.render()))
        res.headers.add(name: "Content-Type", value: "application/rss+xml; charset=utf-8")
        return request.eventLoop.makeSucceededFuture(res)
    }
}
