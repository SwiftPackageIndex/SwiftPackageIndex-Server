
extension Dictionary where Key == String, Value == String {
    func queryString(includeSeparator: Bool = true) -> String {
        guard !isEmpty else { return "" }
        let query: String = keys.sorted()
            .map { key in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let value = self[key]!
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        return includeSeparator ? "?" + query : query
    }
}
