import Plot


enum BuildIndex {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Build Results"),
                .p(
                    .strong("\(model.buildCount)"),
                    .text(" completed \("build".pluralized(for: model.buildCount)) for "),
                    .a(
                        .href(model.packageURL),
                        .text(model.packageName)
                    ),
                    .text(".")
                ),
                .ul(
                    .class("matrix"),
                    buildItem(),
                    buildItem(),
                    buildItem()
                )
            )
        }

        func buildItem() -> Node<HTML.ListContext> {
            .li(
                .class("row"),
                .div(
                    .class("row_label"),
                    .div(
                        .div(
                            .strong("Swift 5.3"),
                            .text(" on "),
                            .strong("iOS")
                        )
                    )
                ),
                .div(
                    .class("row_values"),
                    .div(
                        .class("column_label"),
                        .div(
                            .span(
                                .class("stable"),
                                .i(.class("icon stable")),
                                .text("5.4.3")
                            )
                        ),
                        .div(
                            .span(
                                .class("beta"),
                                .i(.class("icon beta")),
                                .text("6.0.0.beta.1")
                            )
                        ),
                        .div(
                            .span(
                                .class("branch"),
                                .i(.class("icon branch")),
                                .text("main")
                            )
                        )
                    ),
                    .div(
                        .class("result"),
                        .div(
                            .class("succeeded"),
                            .i(.class("icon matrix_succeeded")),
                            .a(
                                .href("#"),
                                .text("View Build Log")
                            )
                        ),
                        .div(
                            .class("unknown"),
                            .i(.class("icon matrix_unknown"))
                        ),
                        .div(
                            .class("failed"),
                            .i(.class("icon matrix_failed")),
                            .a(
                                .href("#"),
                                .text("View Build Log")
                            )
                        )
                    )
                )
            )
        }
    }
}
