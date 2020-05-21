
func pluralizedCount(_ count: Int, singular: String, plural: String? = nil) -> String {
    let plural = plural ?? singular + "s"
    switch count {
        case 0:
            return "no \(plural)"
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
