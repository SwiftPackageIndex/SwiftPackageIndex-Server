
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
