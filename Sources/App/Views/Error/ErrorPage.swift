import Plot
import Vapor


final class ErrorPage: PublicPage {
    let status: HTTPStatus

    init(_ status: HTTPStatus) { self.status = status }

    override func content() -> Node<HTML.BodyContext> {
        .div(
            // FIXME
            .h1(.text("ERROR \(status)"))
        )
    }

}
