import Plot

extension Node where Context: HTML.BodyContext {
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

// Awaiting upstreaming in https://github.com/JohnSundell/Plot/pull/66
extension Node where Context: RSSContentContext {
    static func description(_ nodes: Node<HTML.BodyContext>...) -> Node {
        .element(named: "description",
                 nodes: [Node.raw("<![CDATA[\(nodes.render())]]>")])
    }
}

