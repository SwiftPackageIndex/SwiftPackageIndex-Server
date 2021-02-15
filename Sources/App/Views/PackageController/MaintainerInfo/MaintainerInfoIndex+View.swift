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
                .p(
                    .text("Are you the author, or a maintainer of "),
                    .a(
                        .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .none).absoluteURL()),
                        .text(model.packageName)
                    ),
                    .text("? "),
                    .text("Here's what you need to know to make your package's page on the Swift Package Index, and your README both show the best information about your package.")
                ),
                .h3("Compatibility Badges"),
                .p("You can add ",
                    .a(
                        .href("https://shields.io"),
                        "shields.io"
                    ),
                    " badges to your package's README file. Display your package's compatibility with recent versions of Swift, or with different platforms, or both!"
                ),
                .strong("Swift Version Compatibility Badge"),
                .div(
                    .class("badge_markdown"),
                    .form(model.badgeMarkdowDisplay(for: .swiftVersions)),
                    .img(.src(model.badgeURL(for: .swiftVersions)))
                ),
                .strong("Platform Compatibility Badge"),
                .div(
                    .class("badge_markdown"),
                    .form(model.badgeMarkdowDisplay(for: .platforms)),
                    .img(.src(model.badgeURL(for: .platforms)))
                ),
                .p("Copy the Markdown above into your package's README file to show always-up-to-date compatibility status for your package."),
                .h3("Build Compatibility"),
                .p(
                    .text("For information on improving your "),
                    .a(
                        .href(SiteURL.package(.value(model.repositoryOwner), .value(model.repositoryName), .builds).relativeURL()),
                        "package's build results"
                    ),
                    .text(", including why you might want to add a "),
                    .code(".spi.yml"),
                    .text(" which controls the Swift Package Index build system, see the "),
                    .a(
                        .href(SiteURL.docs(.builds).relativeURL()),
                        "build system documentation"
                    ),
                    .text(".")
                )
            )
        }
    }
}
