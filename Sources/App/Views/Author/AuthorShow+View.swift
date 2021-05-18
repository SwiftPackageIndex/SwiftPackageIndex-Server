import Plot


enum AuthorShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Packages by \(model.owner)"
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(.text("Packages authored by \(model.owner)")),
                .ul(
                    .id("package_list"),
                    .group(
                        model.packages.map { package -> Node<HTML.ListContext> in
                            .li(
                                .a(
                                    .href(package.url),
                                    .h4(.text(package.title)),
                                    .p(.text(package.description))
                                )
                            )
                        }
                    )
                ),
                .p(.text("\(model.count) \("package".pluralized(for: model.count))."))
            )
        }
    }

}
