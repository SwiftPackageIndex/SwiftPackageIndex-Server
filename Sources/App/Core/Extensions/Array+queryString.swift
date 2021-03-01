
extension Array where Element == QueryParameter {
    func queryString(includeSeparator: Bool = true) -> String {
        guard !isEmpty else { return "" }
        let query: String = self.map { $0.encodedForQueryString }.joined(separator: "&")
        return includeSeparator ? "?" + query : query
    }
}
