import Foundation


enum Reference: Equatable {
    case branch(String)
    case tag(SemVer)

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
            case .tag(let v):
                return v
        }
    }
}


extension Reference: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .branch) {
            self = .branch(value)
            return
        }
        if let value = try? container.decode(SemVer.self, forKey: .tag) {
            self = .tag(value)
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
            case .tag(let value):
                try container.encode(value, forKey: .tag)
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
            case .tag(let value): return String(describing: value)
        }
    }
}
