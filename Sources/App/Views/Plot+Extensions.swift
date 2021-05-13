import Plot

extension Node where Context == HTML.BodyContext {
    static func small(_ nodes: Node<HTML.BodyContext>...) -> Self {
        .element(named: "small", nodes: nodes)
    }

    static func hr(_ attributes: Attribute<HTML.BodyContext>...) -> Node {
        .selfClosedElement(named: "hr", attributes: attributes)
    }

    static func turboFrame(id: String, source: String? = nil, _ nodes: Node<HTML.BodyContext>...) -> Self {
        let attributes: [Node<HTML.BodyContext>] = [
            .attribute(named: "id", value: id),
            .attribute(named: "src", value: source)
        ]
        return .element(named: "turbo-frame", nodes: attributes + nodes)
    }

    static func spiReadme(_ nodes: Node<HTML.BodyContext>...) -> Self {
        .element(named: "spi-readme", nodes: nodes)
    }
}

extension Node where Context == HTML.AnchorContext {
    static func small(_ nodes: Node<HTML.BodyContext>...) -> Self {
        .element(named: "small", nodes: nodes)
    }
}
