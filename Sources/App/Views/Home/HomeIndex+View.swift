import Plot


enum HomeIndex {
    
    class View: PublicPage {
        
        let model: Model
        
        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }
        
        override func pageDescription() -> String? {
            """
            The Swift Package Index is the place to find the best Swift packages. \
            \(model.statsDescription() ?? "")
            """
        }
        
        override func noScript() -> Node<HTML.BodyContext> {
            .noscript(
                .p("The search function of this site requires JavaScript.")
            )
        }
        
        override func preMain() -> Node<HTML.BodyContext> {
            .section(
                .class("search"),
                .div(
                    .class("inner"),
                    .h3("The place to find Swift packages."),
                    .form(
                        .textarea(
                            .id("query"),
                            .attribute(named: "placeholder", value: "Search"), // TODO: Fix after Plot update
                            .attribute(named: "spellcheck", value: "false"), // TODO: Fix after Plot update
                            .attribute(named: "data-gramm", value: "false"),
                            .autofocus(true),
                            .rows(1)
                        ),
                        .div(
                            .id("results"),
                            .attribute(named: "hidden", value: "true") // TODO: Fix after Plot update
                        )
                    ),
                    .unwrap(model.statsClause()) { $0 }
                )
            )
        }
        
        override func content() -> Node<HTML.BodyContext> {
            .group(
                .div(
                    .class("scta"),
                    .text("This site is entirely funded by community donations. Please consider supporting this project by "),
                    .a(
                        .href("https://github.com/sponsors/SwiftPackageIndex"),
                        "sponsoring the Swift Package Index"
                    ),
                    .text(". "),
                    .strong("Thank you!")
                ),
                .div(
                    .class("recent"),
                    .section(
                        .class("recent_packages"),
                        .h3("Recently Added"),
                        .ul(model.recentPackagesSection())
                    ),
                    .section(
                        .class("recent_releases"),
                        .h3("Recent Releases"),
                        .ul(model.recentReleasesSection())
                    )
                )
            )
        }
        
        override func navItems() -> [Node<HTML.ListContext>] {
            // The default navigation menu, without search.
            [
                .li(
                    .a(
                        .href(SiteURL.addAPackage.relativeURL()),
                        "Add a Package"
                    )
                ),
                .li(
                    .a(
                        .href("https://blog.swiftpackageindex.com"),
                        "Blog"
                    )
                ),
                .li(
                    .a(
                        .href(SiteURL.faq.relativeURL()),
                        "FAQ"
                    )
                )
            ]
        }
        
    }
    
}
