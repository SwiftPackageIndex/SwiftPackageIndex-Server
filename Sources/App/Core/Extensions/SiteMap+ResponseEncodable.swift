import Plot
import Vapor


extension SiteMap: ResponseEncodable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        let res = Response(status: .ok, body: .init(string: self.render()))
        res.headers.add(name: "Content-Type", value: "text/xml")
        return request.eventLoop.makeSucceededFuture(res)
    }
}
