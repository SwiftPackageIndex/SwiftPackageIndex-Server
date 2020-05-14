import Plot

class PublicPage {

    /// The page's full HTML document.
    /// - Returns: A fully formed page inside a <html> element.
    func document() -> HTML {
        HTML(head(),
             body())
    }

    /// The page head.
    /// - Returns: A <head> element.
    func head() -> Node<HTML.DocumentContext> {
        .head(.viewport(.accordingToDevice, initialScale: 1),
              .title("Swift Package Index"),
              .link(.rel(.stylesheet),
                    .href("https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css"))
        )
    }

    /// The page body.
    /// - Returns: A <body> element.
    func body() -> Node<HTML.DocumentContext> {
        .body(header(),
              content(),
              footer())
    }

    /// The site header, including the site navigation.
    /// - Returns: A <header> element.
    func header() -> Node<HTML.BodyContext> {
        .header(
            .h1(
                .img(.src("/images/logo.svg")),
                "Swift Package Index"
            ),
            .nav(
                .ul(
                    .group(navItems())
                )
            )
        )
    }

    /// List items to be rendered in the site navigation menu.
    /// - Returns: An array of <li> elements.
    func navItems() -> [Node<HTML.ListContext>] {
        [.li(.a(.href("#"), "Add a Package")),
         .li(.a(.href("#"), "About")),
         .li(.a(.href("#"), "Search"))]
    }

    /// The page's main content.
    /// - Returns: A <main> element
    func content() -> Node<HTML.BodyContext> {
        .main(.p("Override ",
                 .pre(.code("content()")),
                 " to change this page's content."))
    }

    /// The site footer, including all footer links.
    /// - Returns: A <footer> element.
    func footer() -> Node<HTML.BodyContext> {
        .footer(.ul(.li()))
    }

}
