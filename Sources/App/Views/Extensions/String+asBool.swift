
extension String {

    var asBool: Bool? {
        switch lowercased() {
            case "1", "yes", "true": return true
            case "0", "no", "false": return false
            default: return Bool(self)
        }
    }

}
