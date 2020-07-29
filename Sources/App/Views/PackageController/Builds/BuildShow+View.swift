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
                    .div(
                        .class("lozenge \(model.buildInfo.status.cssClass)"),
                        .i(.class("icon \(model.buildInfo.status.cssIcon)")),
                        .text(model.buildInfo.status.text)
                    )
                ),
                .div(
                    .class("split"),
                    .div(
                        .text("Built "),
                        .a(
                            .href(model.packageURL),
                            .text(model.packageName)
                        ),
                        .text(" with "),
                        .strong(.text(model.buildInfo.swiftVersion.longDisplayName)),
                        .text(" for "),
                        .strong(.text(model.buildInfo.platform.displayName)),
                        .unwrap(model.buildInfo.xcodeVersion) {
                            .group(
                                .text(" using "),
                                .strong(.text($0))
                            )
                        },
                        .text(".")
                    ),
                    .div(
                        .a(
                            .href(model.buildsURL),
                            "View all builds"
                        )
                    )
                ),
                .h3("Build Command"),
                .pre(
                    .code(
                        .text(model.buildInfo.buildCommand)
                    )
                ),
                .h3("Build Log"),
                .pre(
                    .id("build_log"),
                    .code(
                        .text(model.buildInfo.logs)
                    )
                )
            )
        }
    }

}


private extension Build.Status {
    var text: String {
        switch self {
            case .ok: return "Build Succeeded"
            case .failed: return "Build Failed"
        }
    }

    var cssClass: String {
        switch self {
            case .ok: return "green"
            case .failed: return "red"
        }
    }

    var cssIcon: String {
        switch self {
            case .ok: return "matrix_succeeded"
            case .failed: return "matrix_failed"
        }
    }
}
