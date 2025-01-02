import Vapor

// Replica of the Vapor RouteLoggingMiddleware that's tweaked to explicitly expose the cf-ray header in the logger metadata for the request.
public final class CFRayRouteLoggingMiddleware: Middleware {
    public let logLevel: Logger.Level
    
    public init(logLevel: Logger.Level = .info) {
        self.logLevel = logLevel
    }
    
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let cfray = request.headers.first(name: "cf-ray") else {
            return next.respond(to: request)
        }
        request.logger[metadataKey: "cf-ray"] = .string(cfray)
        request.logger.log(level: self.logLevel, "\(request.method) \(request.url.path.removingPercentEncoding ?? request.url.path)")
        return next.respond(to: request)
    }
}
