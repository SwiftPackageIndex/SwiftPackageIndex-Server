import Plot
import Vapor


// based on LeafErrorMiddleware
// https://github.com/brokenhandsio/leaf-error-middleware

public final class ErrorMiddleware: Middleware {
    
    public func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        next.respond(to: req)
            .flatMapError { error in
                let abortError = error as? AbortError ?? Abort(.internalServerError)

                let reportError = abortError.status.code >= 500
                    ? Current.reportError(req.client, .critical, error)
                    : req.eventLoop.future()

                return reportError.flatMap {
                    Current.logger()?.critical("ErrorPage.View: \(error.localizedDescription)")
                    return ErrorPage.View(path: req.url.path, error: abortError)
                        .document()
                        .encodeResponse(for: req, status: abortError.status)
                }
            }
    }

}
