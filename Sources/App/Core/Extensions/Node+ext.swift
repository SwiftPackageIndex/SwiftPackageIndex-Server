import Plot


extension Node where Context: HTML.BodyContext {
    // TODO: remove once it's upstreamed via https://github.com/JohnSundell/Plot/pull/57
    static func a(href url: URLRepresentable, _ nodes: Node<HTML.BodyContext>...) -> Node {
        .element(named: "a", nodes: [
            // 'string' is inaccessible due to 'internal' protection level
            //    .attribute(named: "href", value: url.string)
            // add to Plot for access
            .attribute(named: "href", value: url.description)
        ] + nodes)
    }
}
