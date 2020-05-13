import Plot

class PublicPage {

    /// The page's full HTML document.
    /// - Returns: A fully formed page inside a <html> element.
    func document() -> HTML {
        HTML(.head(),
             .body())
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
        .header(.h1("Swift Package Index"),
                .nav())
    }

    /// The menu navigation inside the site header, including all menu links.
    /// - Returns: A <nav> element.
    func nav() -> Node<HTML.BodyContext> {
        .ul(.li("Add a Package"),
            .li("About"))
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
