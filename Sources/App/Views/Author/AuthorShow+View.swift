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
                    .text("These packages are available as a package collection, "),
                    .a(
                        .href(SiteURL.packageCollections.relativeURL()),
                        "usable in Xcode 13 or the Swift Package Manager 5.5"
                    ),
                    .text(".")
                ),
                .form(
                    .class("copyable_input"),
                    .input(
                        .type(.text),
                        .data(named: "button-name", value: "Copy Package Collection URL"),
                        .data(named: "event-name", value: "Copy Package Collection URL Button"),
                        .value(SiteURL.packageCollection(.value(model.owner)).absoluteURL()),
                        .readonly(true)
                    )
                ),
                .hr(.class("minor")),
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
                    .strong("\(model.count) \("package".pluralized(for: model.count)).")
                )
            )
        }
    }

}
