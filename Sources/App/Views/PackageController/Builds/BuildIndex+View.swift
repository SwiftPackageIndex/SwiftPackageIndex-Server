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
                .forEach(SwiftVersion.allActive.reversed()) { swiftVersion in
                    .group(
                        .element(named: "hr"),
                        .h3(.text(swiftVersion.longDisplayName)),
                        .ul(
                            .class("matrix"),
                            .group(model.buildMatrix[swiftVersion].map(\.node))
                        )
                    )
                }
            )
        }

    }
}
