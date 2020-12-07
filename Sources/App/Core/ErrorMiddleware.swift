import Plot
import Vapor


// based on LeafErrorMiddleware
// https://github.com/brokenhandsio/leaf-error-middleware

public final class ErrorMiddleware: Middleware {
    
    public func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        next.respond(to: req)
            .flatMapError { error in
                let abortError = error as? AbortError ?? Abort(.internalServerError)
                let statusCode = abortError.status.code

                let reportError = statusCode >= 500
                    ? Current.reportError(req.client, .critical, error)
                    : req.eventLoop.future()

                return reportError.flatMap {
                    statusCode >= 500
                        ? Current.logger()?.critical("ErrorPage.View \(statusCode): \(error.localizedDescription)")
                        : Current.logger()?.error("ErrorPage.View \(statusCode): \(error.localizedDescription)")
                    return ErrorPage.View(path: req.url.path, error: abortError)
                        .document()
                        .encodeResponse(for: req, status: abortError.status)
                }
            }
    }

}
