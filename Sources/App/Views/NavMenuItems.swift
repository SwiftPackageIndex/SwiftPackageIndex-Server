import Plot

enum NavMenuItem {
    case sponsorCTA
    case addPackage
    case blog
    case faq
    case search

    func listNode() -> Node<HTML.ListContext> {
        switch self {
            case .sponsorCTA:
                return .li(
                    .class("menu_scta"),
                    .a(
                        .id("menu_scta"),
                        .href("https://github.com/sponsors/SwiftPackageIndex")
                    ),
                    .div(
                        .id("menu_scta_help"),
                        .text("This site is entirely funded by community donations. Please consider sponsoring this project. "),
                        .strong("Thank you!")
                    )
                )
            case .addPackage:
                return .li(
                    .a(
                        .href(SiteURL.addAPackage.relativeURL()),
                        "Add a Package"
                    )
                )
            case .blog:
                return .li(
                    .a(
                        .href("https://blog.swiftpackageindex.com"),
                        "Blog"
                    )
                )
            case .faq:
                return .li(
                    .a(
                        .href(SiteURL.faq.relativeURL()),
                        "FAQ"
                    )
                )
            case .search:
                return .li(
                    .searchForm()
                )
        }
    }
}
