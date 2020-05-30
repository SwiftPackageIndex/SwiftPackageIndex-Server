import Plot
import Vapor


// based on LeafErrorMiddleware
// https://github.com/brokenhandsio/leaf-error-middleware

public final class ErrorMiddleware: Middleware {

    public func respond(to req: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        next.respond(to: req)
            .flatMapError { error in
                if let abort = error as? AbortError {
                    return self.handleError(for: req, status: abort.status)
                } else {
                    return self.handleError(for: req, status: .internalServerError)
                }
        }
    }

    private func handleError(for req: Request, status: HTTPStatus) -> EventLoopFuture<Response> {
        ErrorPage(status).document().encodeResponse(for: req)
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
