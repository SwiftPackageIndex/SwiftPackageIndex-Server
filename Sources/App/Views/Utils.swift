
func pluralize(count: Int, singular: String, plural: String? = nil) -> String {
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
