import Plot


// TODO: sas: move under Page? Or move some Page extensions here? (matter of style, really
// but it's probably better not to mix both or it'll get confusing with leading dots).
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
