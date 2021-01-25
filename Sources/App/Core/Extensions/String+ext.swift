import Foundation


extension String {
    var droppingGithubComPrefix: String {
        if lowercased().hasPrefix(Constants.githubComPrefix) {
            return String(dropFirst(Constants.githubComPrefix.count))
        }
        return self
    }
    
    var droppingGitExtension: String {
        if lowercased().hasSuffix(Constants.gitSuffix) {
            return String(dropLast(Constants.gitSuffix.count))
        }
        return self
    }
}


extension String.StringInterpolation {

    mutating func appendInterpolation<T: CustomStringConvertible>(_ value: T?) {
        appendInterpolation(value, defaultValue: "nil")
    }

    mutating func appendInterpolation<T: CustomStringConvertible>(
        _ value: T?,
        defaultValue: @autoclosure () -> String) {
        appendInterpolation(value ?? defaultValue() as CustomStringConvertible)
    }

}
