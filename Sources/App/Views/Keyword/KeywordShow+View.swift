import Plot


enum KeywordShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Packages for \(model.keyword)"
        }

        override func pageDescription() -> String? {
            let packagesClause = model.packages.count > 1 ? "1 package" : "\(model.packages.count) packages"
            return "The Swift Package Index is indexing \(packagesClause) for \(model.keyword)."
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(
                    .class("trimmed"),
                    .text("Packages for \(model.keyword)")
                ),
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
                .p(
                    .strong("\(model.packages.count) \("package".pluralized(for: model.packages.count)).")
                )
            )
        }
    }

}
