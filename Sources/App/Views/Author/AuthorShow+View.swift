import Plot


enum AuthorShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            "Packages by \(model.ownerName)"
        }

        override func pageDescription() -> String? {
            let packagesClause = model.packages.count > 1 ? "1 package" : "\(model.packages.count) packages"
            return "The Swift Package Index is indexing \(packagesClause) authored by \(model.ownerName)."
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2(
                    .class("trimmed"),
                    .text("Packages authored by \(model.ownerName)")
                ),
                .p(
                    .text("All "),
                    .strong("\(model.count) \("package".pluralized(for: model.count)) "),
                    .text("listed here are available as a "),
                    .a(
                        .href(SiteURL.packageCollection(.value(model.owner)).relativeURL()),
                        "package collection"
                    ),
                    .text(". Learn more about "),
                    .a(
                        .href(SiteURL.packageCollections.relativeURL()),
                        "package collections"
                    ),
                    .text(".")
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
                )
            )
        }
    }

}
