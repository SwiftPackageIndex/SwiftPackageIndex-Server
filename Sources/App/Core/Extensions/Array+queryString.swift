
extension Array where Element == QueryParameter {
    func queryString(includeSeparator: Bool = true, encoded: Bool = true) -> String {
        guard !isEmpty else { return "" }
        let query: String = self
            .map { encoded ? $0.encodedForQueryString : $0.unencodedQueryString }
            .joined(separator: "&")
        return includeSeparator ? "?" + query : query
    }
}
