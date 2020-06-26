import Plot


extension Array where Element == Node<HTML.BodyContext> {
    func joined(separator: Node<HTML.BodyContext>) -> [Node<HTML.BodyContext>] {
        guard let first = first else { return [] }
        return dropFirst().reduce([first]) { $0 + [separator, $1] }
    }
}

