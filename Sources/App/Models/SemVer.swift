import Vapor


struct SemVer: Content, Equatable {
    var major: Int
    var minor: Int
    var patch: Int
}


extension SemVer: ExpressibleByStringLiteral {
    // TODO: sas-2020-04-29: This can/should probably be improved...
    // Or should we just save versions as flat strings?
    init(stringLiteral value: StringLiteralType) {
        let parts = value.split(separator: ".").map(String.init).compactMap(Int.init)
        switch parts.count {
            case 1: self = .init(major: parts[0], minor: 0, patch: 0)
            case 2: self = .init(major: parts[0], minor: parts[1], patch: 0)
            case 3: self = .init(major: parts[0], minor: parts[1], patch: parts[2])
            default: self = .init(major: 0, minor: 0, patch: 0)
        }
    }
}


extension SemVer {
    // TODO: sas-2020-05-03: This could also be init?(rawValue: String) but that might be confusing
    // with the existing init(stringLiteral:) that we need to db decoding.
    static func parse(_ string: String) -> Self? {
        let parts = string.split(separator: ".").map(String.init)
        guard parts.allSatisfy({ $0.contained(in: .decimalDigits) }) else { return nil }
        let numbers = parts.compactMap(Int.init)
        switch numbers.count {
            case 1: return .init(major: numbers[0], minor: 0, patch: 0)
            case 2: return .init(major: numbers[0], minor: numbers[1], patch: 0)
            case 3: return .init(major: numbers[0], minor: numbers[1], patch: numbers[2])
            default: return nil
        }
    }
}
