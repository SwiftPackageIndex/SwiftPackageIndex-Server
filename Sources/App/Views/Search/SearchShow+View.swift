import Plot


extension SearchShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(.text("Results for \(model.query)")),
                .ul(
                    .class("list"),
                    .group(
                        model.results.map { result -> Node<HTML.ListContext> in
                            .li(
                                .a(
                                    .href(result.packageURL ?? "-"),
                                    .h4(.text(result.packageName ?? "-")),
                                    .p(.text(result.summary ?? "-"))
                                )
                            )
                        }
                    )
                ),
                .p(.text("\(model.results.count) \("result".pluralized(for: model.results.count))."))
            )
        }
    }

}
