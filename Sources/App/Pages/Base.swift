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


extension Node where Context == HTML.BodyContext {
    static func container(_ children: Node...) -> Node {
        .div(
            .attribute(.class("container")),
            .group(children)
        )
    }

    static func row(_ children: Node...) -> Node {
        .div(
            .attribute(.class("row")),
            .group(children)
        )
    }
}


extension Node where Context == HTML.FormContext {
    static func row(_ nodes: Node<HTML.BodyContext>...) -> Node {
        .div(
            .attribute(.class("row")),
            .group(nodes)
        )
    }
}
