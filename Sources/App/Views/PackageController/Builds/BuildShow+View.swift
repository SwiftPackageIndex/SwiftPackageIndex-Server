import Plot


enum BuildShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Build Details"),
                .pre(.text(model.logs))
            )
        }
    }

}


extension BuildShow {

    struct Model {
        var logs: String

        internal init(logs: String) {
            self.logs = logs
        }

        init(build: App.Build) {
            logs = build.logs ?? ""
        }
    }

}
