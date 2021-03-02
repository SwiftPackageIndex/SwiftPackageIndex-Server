import Plot

extension Node where Context == HTML.BodyContext {
    static func small(_ nodes: Node<HTML.BodyContext>...) -> Self {
        .element(named: "small", nodes: nodes)
    }

    static func hr(_ attributes: Attribute<HTML.BodyContext>...) -> Node {
        .selfClosedElement(named: "hr", attributes: attributes)
    }
}

// TODO: Does this really have to be duplicated?
extension Node where Context == HTML.AnchorContext {
    static func small(_ nodes: Node<HTML.BodyContext>...) -> Self {
        .element(named: "small", nodes: nodes)
    }
}

extension Node where Context == HTML.FormContext {
    public static func input(autofocus: Bool = true, _ attributes: Attribute<HTML.InputContext>...) -> Self {
        autofocus
            ? .selfClosedElement(named: "input", attributes: attributes + [.attribute(named: "autofocus", value: "true")])
            : .selfClosedElement(named: "input", attributes: attributes)
    }
}
