import Plot

extension Node where Context == HTML.BodyContext {
    static func small(_ nodes: Node<HTML.BodyContext>...) -> Self {
        .element(named: "small", nodes: nodes)
    }

    static func hr(_ attributes: Attribute<HTML.BodyContext>...) -> Node {
        .selfClosedElement(named: "hr", attributes: attributes)
    }
}
