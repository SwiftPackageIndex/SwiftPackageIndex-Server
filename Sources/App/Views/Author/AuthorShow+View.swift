import Plot


enum AuthorShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .class("author recent"), // 'recent' is temporary while I figure out how to regenerate the CSS file from SCSS
                .div(
                    .h2(.text("Showing \(model.count) packages from '\(model.owner)'"))
                ),
                .hr(),
                .ul(
                    .group(
                        model.packages.map { package -> Node<HTML.ListContext> in
                            .li(
                                .a(
                                    .href(package.url),
                                    .text(package.title)
                                ),
                                .element(named: "small", text: package.description)
                            )
                        }
                    )
                )
            )
        }
    }

}
