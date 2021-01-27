import Plot


// MARK: - Pluralisation

func pluralizedCount(_ count: Int, singular: String, plural: String? = nil, capitalized: Bool = false) -> String {
    let plural = plural ?? singular + "s"
    switch count {
        case 0:
            return capitalized ? "No \(plural)" : "no \(plural)"
        case 1:
            return "1 \(singular)"
        default:
            return "\(count) \(plural)"
    }
}


extension String {
    func pluralized(for count: Int, plural: String? = nil) -> String {
        let plural = plural ?? self + "s"
        switch count {
            case 0:
                return plural
            case 1:
                return self
            default:
                return plural
        }
    }
}


// MARK: - Conjunction

func listPhrase(opening: Node<HTML.BodyContext> = "",
                nodes: [Node<HTML.BodyContext>],
                ifEmpty: Node<HTML.BodyContext>? = nil,
                conjunction: Node<HTML.BodyContext> = " and ",
                closing: Node<HTML.BodyContext> = "") -> [Node<HTML.BodyContext>] {
    switch nodes.count {
        case 0:
            return ifEmpty.map { [$0] } ?? []
        case 1:
            return [opening, nodes[0], closing]
        case 2:
            return [opening, nodes[0], conjunction, nodes[1], closing]
        default:
            let start: [Node<HTML.BodyContext>]
                = [opening, nodes.first!]
            let middle: [[Node<HTML.BodyContext>]] = nodes[1..<(nodes.count - 1)].map {
                [", ", $0]
            }
            let end: [Node<HTML.BodyContext>] =
                [",", conjunction, nodes.last!, closing]
            return middle.reduce(start) { $0 + $1 } + end
    }
}
