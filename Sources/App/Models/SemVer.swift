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
