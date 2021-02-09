import Plot

enum MaintainerInfoIndex {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Information for \(model.packageName) Maintainers"),
                .p("Are you the author, or a maintainer of \(model.packageName)?")
            )
        }
    }
}
