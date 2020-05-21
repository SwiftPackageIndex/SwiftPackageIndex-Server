import Foundation
import ShellOut


enum GitError: LocalizedError {
    case invalidTimestamp
}


enum Git {

    static func tag(at path: String) throws -> [Reference] {
        let tags = try Current.shell.run(command: .init(string: "git tag"), at: path)
        return tags.split(separator: "\n")
            .map(String.init)
            .compactMap(SemVer.init)
            .map { Reference.tag($0) }
    }

    static func revList(_ reference: Reference, at path: String) throws -> CommitHash {
        try Current.shell.run(command: .init(string: "git rev-list -n 1 \(reference)"))
    }

    static func showDate(_ commit: CommitHash, at path: String) throws -> Date {
        let res = try Current.shell.run(command: .init(string: "git show -s --format=%ct \(commit)"))
        guard let timestamp = TimeInterval(res) else {
            throw GitError.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func revInfo(_ reference: Reference, at path: String) throws -> RevisionInfo {
        let hash = try revList(reference, at: path)
        let date = try showDate(hash, at: path)
        return .init(commit: hash, date: date)
    }

    struct RevisionInfo: Equatable {
        let commit: CommitHash
        let date: Date
    }
}
