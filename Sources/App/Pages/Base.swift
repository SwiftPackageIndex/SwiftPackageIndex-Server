import Plot


func myhead(title: String) -> Node<HTML.DocumentContext> {
    .head(
        .meta(.charset(.utf8)),
        .meta(.name("viewport"), .content("width=device-width, initial-scale=1, shrink-to-fit=no")),
        .link(
            .rel(.stylesheet),
            .href("https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"),
            .integrity("sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO"),
            .init(name: "crossorigin", value: "anonymous")
        ),
        .link(
            .href("/grid.css"),
            .rel(.stylesheet)
        ),
        .title(title)
    )
}


func container(_ children: Node<HTML.BodyContext>...) -> Node<HTML.BodyContext> {
    .div(
        .attribute(.class("container")),
        .group(children)
    )
}


func row(_ children: Node<HTML.BodyContext>...) -> Node<HTML.BodyContext> {
    .div(
        .attribute(.class("row")),
        .group(children)
    )
}
