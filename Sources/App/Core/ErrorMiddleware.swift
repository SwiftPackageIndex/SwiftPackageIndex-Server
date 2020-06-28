import Plot
import Vapor


// based on LeafErrorMiddleware
// https://github.com/brokenhandsio/leaf-error-middleware

public final class ErrorMiddleware: Middleware {
    
    public func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        next.respond(to: req)
            .flatMapError { error in
                if let abort = error as? AbortError {
                    return self.handleError(for: req, error: abort)
                } else {
                    return self.handleError(for: req, error: Abort(.internalServerError))
                }
            }
    }
    
    private func handleError(for req: Request, error: AbortError) -> EventLoopFuture<Response> {
        let alert = error.status.code >= 500
            ? Current.reportError(req.client, .critical, error)
            : req.eventLoop.future()
        let model = ErrorPage.Model(error)
        return alert.flatMap { ErrorPage.View(path: req.url.path,
                                              model: model).document().encodeResponse(for: req,
                                                                                      status: error.status) }
    }
}


extension HTTPStatus {
    internal init(_ error: Error) {
        if let abort = error as? AbortError {
            self = abort.status
        } else {
            self = .internalServerError
        }
    }
}
