import Plot
import Vapor

enum ErrorPage {

    final class View: PublicPage {
        let model: Model

        init(_ model: Model) {
            self.model = model
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                // Note: The copy in this header tag intentionally matches the copy in `search_core.js`.
                .h2("Something went wrong. Sorry!"),
                .p(.text(model.errorMessage))
            )
        }

    }

}
