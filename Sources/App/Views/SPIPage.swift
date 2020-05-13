import Plot


/// Namespace for pages/views, holding generic, reusable elements
enum SPIPage {

    /// The page's full HTML document.
    /// - Returns: A fully formed page inside a <html> element.
    static func document(_ content: Node<HTML.BodyContext>) -> HTML {
        HTML(head(),
             body(content))
    }

    /// The page head.
    /// - Returns: A <head> element.
    static func head() -> Node<HTML.DocumentContext> {
        .head(.viewport(.accordingToDevice, initialScale: 1),
              .title("Swift Package Index"),
              .link(.rel(.stylesheet),
                    .href("https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css"))
        )
    }

    /// The page body.
    /// - Returns: A <body> element.
    static func body(_ content: Node<HTML.BodyContext>) -> Node<HTML.DocumentContext> {
        .body(header(),
              content,
              footer())
    }

    /// The site header, including the site navigation.
    /// - Returns: A <header> element.
    static func header() -> Node<HTML.BodyContext> {
        .header(.h1("Swift Package Index"),
                .nav())
    }

    /// The menu navigation inside the site header, including all menu links.
    /// - Returns: A <nav> element.
    static func nav() -> Node<HTML.BodyContext> {
        .ul(.li("Add a Package"),
            .li("About"))
    }

    /// The site footer, including all footer links.
    /// - Returns: A <footer> element.
    static func footer() -> Node<HTML.BodyContext> {
        .footer(.ul(.li()))
    }
}
