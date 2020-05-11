import Foundation
import ShellOut


// TODO: remove after upstream merge to JohnSundell/ShellOut
// https://github.com/JohnSundell/ShellOut/pull/48
extension ShellOutCommand {
    private static func git(allowingPrompt: Bool) -> String {
        allowingPrompt ? "git" : "env GIT_TERMINAL_PROMPT=0 git"
    }

    static func gitClone(url: URL, to path: String? = nil, allowingPrompt: Bool) -> ShellOutCommand {
        var command = "\(git(allowingPrompt: allowingPrompt)) clone \(url.absoluteString)"
        path.map { command.append(argument: $0) }
        command.append(" --quiet")

        return ShellOutCommand(string: command)
    }

    static func gitPull(remote: String? = nil, branch: String? = nil, allowingPrompt: Bool) -> ShellOutCommand {
        var command = "\(git(allowingPrompt: allowingPrompt)) pull"
        remote.map { command.append(argument: $0) }
        branch.map { command.append(argument: $0) }
        command.append(" --quiet")

        return ShellOutCommand(string: command)
    }
}


private extension String {
    func appending(argument: String) -> String {
        return "\(self) \"\(argument)\""
    }

    mutating func append(argument: String) {
        self = appending(argument: argument)
    }
}
