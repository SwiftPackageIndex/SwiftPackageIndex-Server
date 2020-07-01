import Foundation


extension NSRegularExpression {
    convenience init(_ pattern: String, options: NSRegularExpression.Options) {
        do {
            try self.init(pattern: pattern, options: options)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }
}


extension NSRegularExpression {
    func matches(_ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)
        return firstMatch(in: string, options: [], range: range) != nil
    }
    
    func matchGroups(_ string: String, options: NSRegularExpression.Options = []) -> [String] {
        let range = NSRange(string.startIndex..., in: string)
        guard let match = firstMatch(in: string, options: [], range: range) else { return [] }
        
        // Skip over index 0 which is the range of the whole match
        return (1...numberOfCaptureGroups).map {
            if let r = Range(match.range(at: $0), in: string) {
                return String(string[r])
            } else {
                return ""
            }
        }
    }
}
