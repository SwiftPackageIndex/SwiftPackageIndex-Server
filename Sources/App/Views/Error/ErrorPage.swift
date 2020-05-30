import Plot
import Vapor


final class ErrorPage: PublicPage {
    let status: HTTPStatus
    let error: AbortError?

    init(status: HTTPStatus, error: AbortError?) {
        self.status = status
        self.error = error
    }

    override func content() -> Node<HTML.BodyContext> {
        .div(
            // FIXME
            .h1(.text("ERROR \(status)"))
        )
    }

}
