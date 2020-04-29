//
//  html.swift
//  sc-web
//
//  Created by Sven A. Schmidt on 03/10/2018.
//

import Foundation


infix operator =>
func => <A> (key: HTML.Attribute.Key<A>, value: A) -> HTML.Attribute {
    return .init(key.key, "\(value)")
}



struct HTML {

    struct Attribute {

        let key: String
        let value: String

        init(_ key: String, _ value: String) {
            self.key = key
            self.value = value
        }

        struct Key<A> {
            let key: String
            init (_ key: String) { self.key = key }
        }

    }

    typealias Tag = String


    enum Node {
        indirect case el(Tag, [Attribute], [Node])
        case text(String)
    }

}

extension HTML.Node {

    static func head(_ children: [HTML.Node]) -> HTML.Node {
        return .el("head", [], children)
    }

    static func html(_ children: [HTML.Node]) -> HTML.Node {
        return html([], children)
    }

    static func html(_ attrs: [HTML.Attribute],_ children: [HTML.Node]) -> HTML.Node {
        return .el("html", attrs, children)
    }

    static func meta(_ attrs: [HTML.Attribute]) -> HTML.Node {
        return .el("meta", attrs, [])
    }

    static func link(_ attrs: [HTML.Attribute]) -> HTML.Node {
        return .el("link", attrs, [])
    }

    static func title(_ title: String) -> HTML.Node {
        return .el("title", [], [.text(title)])
    }

    static func body(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("body", [], children)
    }

    static func body(_ children: [HTML.Node]) -> HTML.Node {
        return body([], children)
    }

    static func header(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("header", attrs, children)
    }

    static func header(_ children: [HTML.Node]) -> HTML.Node {
        return .el("header", [], children)
    }

    static func h1(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("h1", attrs, children)
    }

    static func h1(_ children: [HTML.Node]) -> HTML.Node {
        return .el("h1", [], children)
    }

    static func h2(_ children: [HTML.Node]) -> HTML.Node {
        return .el("h2", [], children)
    }

    static func p(_ node: HTML.Node) -> HTML.Node {
        return .el("p", [], [node])
    }

    static func p(_ children: [HTML.Node]) -> HTML.Node {
        return .el("p", [], children)
    }

    static func p(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("p", attrs, children)
    }

    static func div(_ children: [HTML.Node]) -> HTML.Node {
        return .el("div", [], children)
    }

    static func div(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("div", attrs, children)
    }

    static func dd(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("dd", attrs, children)
    }

    static func dd(_ attrs: [HTML.Attribute], _ text: String) -> HTML.Node {
        return .el("dd", attrs, [.text(text)])
    }

    static func dl(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("dl", attrs, children)
    }

    static func dt(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("dt", attrs, children)
    }

    static func dt(_ attrs: [HTML.Attribute], _ text: String) -> HTML.Node {
        return .el("dt", attrs, [.text(text)])
    }

    static func pre(_ children: [HTML.Node]) -> HTML.Node {
        return .el("pre", [], children)
    }

    static func pre(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("pre", attrs, children)
    }

    static func a(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("a", attrs, children)
    }

    static func a(href: String, text: String) -> HTML.Node {
        return .el("a", [.href => href], [.text(text)])
    }

    static func img(_ attrs: [HTML.Attribute]) -> HTML.Node {
        return .el("img", attrs, [])
    }

    static func script(_ attrs: [HTML.Attribute], _ children: [HTML.Node] = []) -> HTML.Node {
        return .el("script", attrs, children)
    }

    static func form(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("form", attrs, children)
    }

    static func label(_ children: [HTML.Node]) -> HTML.Node {
        return .el("label", [], children)
    }

    static func label(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("label", attrs, children)
    }

    static func input(_ attrs: [HTML.Attribute]) -> HTML.Node {
        return .el("input", attrs, [])
    }

    static func table(_ children: [HTML.Node]) -> HTML.Node {
        return .el("table", [], children)
    }

    static func table(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("table", attrs, children)
    }

    static func thead(_ children: [HTML.Node]) -> HTML.Node {
        return .el("thead", [], children)
    }

    static func thead(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("thead", attrs, children)
    }

    static func th(_ children: [HTML.Node]) -> HTML.Node {
        return .el("th", [], children)
    }

    static func th(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("th", attrs, children)
    }

    static func tr(_ children: [HTML.Node]) -> HTML.Node {
        return .el("tr", [], children)
    }

    static func tr(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("tr", attrs, children)
    }

    static func tbody(_ children: [HTML.Node]) -> HTML.Node {
        return .el("tbody", [], children)
    }

    static func tbody(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("tbody", attrs, children)
    }

    static func td(_ children: [HTML.Node]) -> HTML.Node {
        return .el("td", [], children)
    }

    static func td(_ attrs: [HTML.Attribute], _ children: [HTML.Node]) -> HTML.Node {
        return .el("td", attrs, children)
    }

}


extension HTML.Node {
    var tagName: HTML.Tag? {
        switch self {
        case let .el(tag, _, _):
            return tag
        default:
            return nil
        }
    }
}


extension HTML.Node: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .text(value)
    }
}


extension HTML.Tag {
    var closing: HTML.Tag {
        if self.starts(with: "/") {
            return self
        } else {
            return "/" + self
        }
    }
}


extension HTML.Attribute.Key where A == String {
    static let action = HTML.Attribute.Key<String>("action")
    static let charset = HTML.Attribute.Key<String>("charset")
    static let `class` = HTML.Attribute.Key<String>("class")
    static let content = HTML.Attribute.Key<String>("content")
    static let crossorigin = HTML.Attribute.Key<String>("crossorigin")
    static let enctype = HTML.Attribute.Key<String>("enctype")
    static let `for` = HTML.Attribute.Key<String>("for")
    static let href = HTML.Attribute.Key<String>("href")
    static let id = HTML.Attribute.Key<String>("id")
    static let integrity = HTML.Attribute.Key<String>("integrity")
    static let lang = HTML.Attribute.Key<String>("lang")
    static let method = HTML.Attribute.Key<String>("method")
    static let nameKey = HTML.Attribute.Key<String>("name")
    static let name = HTML.Attribute.Key<String>("name")
    static let rel = HTML.Attribute.Key<String>("rel")
    static let role = HTML.Attribute.Key<String>("role")
    static let scope = HTML.Attribute.Key<String>("scope")
    static let src = HTML.Attribute.Key<String>("src")
    static let type = HTML.Attribute.Key<String>("type")
    static let value = HTML.Attribute.Key<String>("value")
}


enum HTMLError: Error {
    case invalidHeadTag(HTML.Tag?)
}


extension HTML {// Render functinos

    static func indent(_ level: Int) -> String {
        guard level >= 0 else {
            return ""
        }
        return String(repeating: "  ", count: level)
    }


    static func render(_ nodes: [Node], level: Int) -> String {
        return nodes.map { render($0, level: level) }.joined(separator: "")
    }


    static func render(_ attributes: [Attribute]) -> String {
        return attributes
            .map { "\($0.key)=\"\($0.value)\"" }
            .joined(separator: " ")
    }


    static func render(_ tag: Tag, _ attrs: [Attribute] = [], level: Int) -> String {
        return indent(level) + "<" + tag + (attrs.count > 0 ? " " + render(attrs) : "") + ">"
    }


    static func render(_ node: Node, level: Int = 0) -> String {
        let cr = level > 0 ? "\n" : ""
        switch node {
        case let .el("html", attrs, children):
            return "<!DOCTYPE HTML>\n"
                + render("html", attrs, level: level)
                + render(children, level: level + 1)
                + "\n</html>"
        case let .el(tag, attrs, _) where ["meta", "link"].contains(tag):
            return cr + render(tag, attrs, level: level)
        case let .el(tag, attrs, children) where children.count == 0:
            // render closing tag on same line if there are no children
            return cr + render(tag, attrs, level: level) + render(tag.closing, level: 0)
        case let .el(tag, attrs, children):
            // don't render whitespace in before pre content
            let contentLevel = (tag == "pre") ? 0 : level + 1
            return cr + render(tag, attrs, level: level)
                + render(children, level: contentLevel)
                + "\n" + render(tag.closing, level: level)
        case let .text(string):
            return cr + indent(level) + string
        }
    }

}
