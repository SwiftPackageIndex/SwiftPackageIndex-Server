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
        
        override func postBody() -> Node<HTML.BodyContext> {
            .structuredData(IndexSchema())
        }
        
        override func noScript() -> Node<HTML.BodyContext> {
            .noscript(
                .p("The search function of this site requires JavaScript.")
            )
        }
        
        override func preMain() -> Node<HTML.BodyContext> {
            .group(
                .p(
                    .class("announcement"),
                    .text("Package collections are new in Swift 5.5 and Xcode 13 beta and "),
                    .a(
                        .href(SiteURL.packageCollections.relativeURL()),
                        "the Swift Package Index supports them TODAY"
                    ),
                    .text("! 🚀")
                ),
                .section(
                    .class("search home"),
                    .div(
                        .class("inner"),
                        .h3("The place to find Swift packages."),
                        .searchForm(),
                        .unwrap(model.statsClause()) { $0 }
                    )
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

        override func navMenuItems() -> [NavMenuItem] {
            [.addPackage, .blog, .faq]
        }
    }
}
