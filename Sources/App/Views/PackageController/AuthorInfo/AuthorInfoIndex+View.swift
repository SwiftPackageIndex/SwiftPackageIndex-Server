import Plot

enum AuthorInfoIndex {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Author Information for \(model.packageName)"),
                .p("Are you the author, or a maintainer of \(model.packageName)?")
            )
        }
    }
}
