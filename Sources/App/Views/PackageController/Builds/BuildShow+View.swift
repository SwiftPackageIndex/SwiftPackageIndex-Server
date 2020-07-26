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
                .div(
                    .class("split"),
                    .h2("Build Information"),
                    .p(
                        .a(
                            .href("#"),
                            "View all builds"
                        )
                    )
                ),
                .p(
                    .text("Built "),
                    .a(
                        .href("#"),
                        "PackageName"
                    ),
                    .text(" with "),
                    .strong("Swift 5.2"),
                    .text(" for "),
                    .strong("iOS"),
                    .text(" using "),
                    // Note for Sven: I'm not sure we have the Xcode version encoded anywhere but we can derive it
                    // from the Swift version. I think it's important to let people know that we're building with a
                    // specific version of Xcode.
                    .strong("Xcode 11.6"),
                    .text(".")
                ),
                .h3("Build Command"),
                .pre(
                    .code(
                        .text("env DEVELOPER_DIR=\"/Applications/Xcode_12_beta_2.app\" xcrun xcodebuild -IDEClonedSourcePackagesDirPathOverride=\"$PWD/.derivedData\" build -scheme \"Nimble\" -destination \"generic/platform=ios\"")
                    )
                ),
                .h3("Build Log"),
                .pre(
                    .id("build_log"),
                    .code(
                        .text(model.logs)
                    )
                )
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
