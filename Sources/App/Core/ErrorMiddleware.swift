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
                    // FIXME: add logger
                    // logger.critical("Showing error page: \(error.localizedDescription)")
                    print("Showing error page: \(error.localizedDescription)")
                    return self.showErrorPage(for: req, error: abortError)
                }
            }
    }

    func showErrorPage(for req: Request, error: AbortError) -> EventLoopFuture<Response> {
        ErrorPage.View(path: req.url.path, error: error)
            .document()
            .encodeResponse(for: req, status: error.status)
    }

}
