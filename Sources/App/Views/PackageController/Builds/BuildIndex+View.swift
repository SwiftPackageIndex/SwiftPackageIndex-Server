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
                    .strong("\(model.completedBuildCount)"),
                    .text(" completed \("build".pluralized(for: model.completedBuildCount)) for "),
                    .a(
                        .href(model.packageURL),
                        .text(model.packageName)
                    ),
                    .text(".")
                ),
                .p(
                    "If you are the author of this package and see unexpected build failures, please check the ",
                    .a(
                        .href("https://swiftpackageindex.com/docs/builds"),
                        "build system FAQ"
                    ),
                    " to see how we derive build parameters. If you still see surprising results, please ",
                    .a(
                        .href("https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/new"),
                        "raise an issue"
                    ),
                    "."
                ),
                .forEach(SwiftVersion.allActive.reversed()) { swiftVersion in
                    .group(
                        .hr(),
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
