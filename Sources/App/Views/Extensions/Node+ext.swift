import Plot


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
