import Plot


enum BuildShow {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func bodyComments() -> Node<HTML.BodyContext> {
            .comment(model.versionId.uuidString)
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Build Information"),
                .div(
                    .class("two_column"),
                    .p(
                        .strong(
                            .class(model.buildInfo.status.cssClass),
                            .text(model.buildInfo.status.text)
                        ),
                        .text(model.buildInfo.status.joiningClause),
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
                    .p(
                        .class("right"),
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

    // There should never be pending or timed-out builds visible on this page (they don't have any details to display) so the these cases are only for completeness.

    var text: String {
        switch self {
            case .ok: return "Successful"
            case .failed: return "Failed"
            case .pending, .timeout: return ""
        }
    }

    var joiningClause: String {
        switch self {
            case .ok: return " build of "
            case .failed: return " to build "
            case .pending, .timeout: return ""
        }
    }

    var cssClass: String {
        switch self {
            case .ok: return "green"
            case .failed: return "red"
            case .pending, .timeout: return ""
        }
    }
}
