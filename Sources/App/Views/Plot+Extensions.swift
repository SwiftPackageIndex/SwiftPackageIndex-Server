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

    static func spinner() -> Self {
        .div(
            .class("spinner"),
            .div(.class("rect1")),
            .div(.class("rect2")),
            .div(.class("rect3")),
            .div(.class("rect4")),
            .div(.class("rect5"))
        )
    }

    static func searchForm(query: String = "", autofocus: Bool = true) -> Self {
        .form(
            .action(SiteURL.search.relativeURL()),
            .searchField(query: query, autofocus: autofocus),
            .button(
                .attribute(named: "type", value: "submit"),
                .div(
                    .attribute(named: "title", value: "Search")
                )
            )
        )
    }
}

extension Node where Context == HTML.FormContext {
    static func searchField(query: String = "", autofocus: Bool = true) -> Self {
        .input(
            .id("query"),
            .name("query"),
            .type(.search),
            .placeholder("Search"),
            .spellcheck(false),
            .autocomplete(false),
            .enableGrammarly(false),
            .attribute(named: "data-focus", value: String(autofocus)),
            .value(query)
        )
    }
}

// Custom attributes specific to the Swift Package Index

extension Attribute where Context == HTML.InputContext {
    static func enableGrammarly(_ isEnabled: Bool) -> Attribute {
        Attribute(name: "data-gramm", value: String(isEnabled))
    }
}

// Awaiting upstreaming in https://github.com/JohnSundell/Plot/pull/66
extension Node where Context: RSSContentContext {
    static func description(_ nodes: Node<HTML.BodyContext>...) -> Node {
        .element(named: "description",
                 nodes: [Node.raw("<![CDATA[\(nodes.render())]]>")])
    }
}

// Awaiting upstreaming in https://github.com/JohnSundell/Plot/pull/68
extension Attribute where Context == HTML.InputContext {
    static func readonly(_ isReadonly: Bool) -> Attribute {
        isReadonly ? Attribute(name: "readonly", value: nil, ignoreIfValueIsEmpty: false) : .empty
    }
}

// Awaiting upstreaming in XXX
extension Attribute where Context: HTML.BodyContext {
    static func spellcheck(_ isEnabled: Bool) -> Attribute {
        Attribute(name: "readonly", value: String(isEnabled))
    }
}

extension Node where Context: HTML.BodyContext {
    static func spellcheck(_ isEnabled: Bool) -> Node {
        .attribute(named: "readonly", value: String(isEnabled))
    }
}

extension Attribute where Context == HTML.InputContext {
    static func spellcheck(_ isEnabled: Bool) -> Attribute {
        Attribute(name: "readonly", value: String(isEnabled))
    }
}
