
extension Array where Element == QueryStringParameter {
    func queryString(includeSeparator: Bool = true) -> String {
        guard !isEmpty else { return "" }
        let query: String = self.map { parameter in
            let encodedKey = parameter.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            let encodedValue = parameter.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        return includeSeparator ? "?" + query : query
    }
}
