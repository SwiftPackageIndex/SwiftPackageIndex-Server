import Foundation


enum Reference: Equatable {
    case branch(String)
    case tag(SemVer, _ tagName: String)

    static func tag(_ semVer: SemVer) -> Self {
        return .tag(semVer, "\(semVer)")
    }

    var isBranch: Bool {
        switch self {
            case .branch: return true
            case .tag:    return false
        }
    }

    var isTag: Bool { !isBranch }

    var semVer: SemVer? {
        switch self {
            case .branch:
                return nil
            case .tag(let v, _):
                return v
        }
    }
}


extension Reference: Codable {
    private struct Tag: Codable {
        var semVer: SemVer
        var tagName: String

        var asReference: Reference { .tag(semVer, tagName) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .branch) {
            self = .branch(value)
            return
        }
        if let value = try? container.decode(Tag.self, forKey: .tag) {
            self = value.asReference
            return
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: container.codingPath,
                                  debugDescription: "none of the required keys found"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .branch(let value):
                try container.encode(value, forKey: .branch)
            case let .tag(semVer, tagName):
                try container.encode(Tag(semVer: semVer, tagName: tagName), forKey: .tag)
        }
    }

    enum CodingKeys: CodingKey, CaseIterable {
        case branch
        case tag
    }
}


extension Reference: CustomStringConvertible {
    var description: String {
        switch self {
            case .branch(let value): return value
            case .tag(_, let value): return value
        }
    }
}
