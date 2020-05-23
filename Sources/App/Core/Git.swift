import Foundation
import ShellOut


enum GitError: LocalizedError {
    case invalidTimestamp
    case invalidRevisionInfo
}


enum Git {

    static func firstCommitDate(at path: String) throws -> Date {
        let res = try Current.shell.run(
            command: .init(string: #"git log --max-parents=0 -n1 --format=format:"%ct""#),
            at: path)
        guard let timestamp = TimeInterval(res) else {
            throw GitError.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func lastCommitDate(at path: String) throws -> Date {
        let res = try Current.shell.run(
            command: .init(string: #"git log -n1 --format=format:"%ct""#),
            at: path)
        guard let timestamp = TimeInterval(res) else {
            throw GitError.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func tag(at path: String) throws -> [Reference] {
        let tags = try Current.shell.run(command: .init(string: "git tag"), at: path)
        return tags.split(separator: "\n")
            .map(String.init)
            .compactMap(SemVer.init)
            .map { Reference.tag($0) }
    }

    static func revList(_ reference: Reference, at path: String) throws -> CommitHash {
        try Current.shell.run(command: .init(string: "git rev-list -n 1 \(reference)"), at: path)
    }

    static func showDate(_ commit: CommitHash, at path: String) throws -> Date {
        let res = try Current.shell.run(command: .init(string: "git show -s --format=%ct \(commit)"),
                                        at: path)
        guard let timestamp = TimeInterval(res) else {
            throw GitError.invalidTimestamp
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func revisionInfo(_ reference: Reference, at path: String) throws -> RevisionInfo {
        let dash = "-"
        let res = try Current.shell.run(
            command: .init(string: #"git log -n1 --format=format:"%H\#(dash)%ct" \#(reference)"#),
            at: path
        )
        let parts = res.components(separatedBy: dash)
        guard parts.count == 2 else { throw GitError.invalidRevisionInfo }
        let hash = parts[0]
        guard let timestamp = TimeInterval(parts[1]) else { throw GitError.invalidTimestamp }
        let date = Date(timeIntervalSince1970: timestamp)
        return .init(commit: hash, date: date)
    }

    struct RevisionInfo: Equatable {
        let commit: CommitHash
        let date: Date
    }
}
