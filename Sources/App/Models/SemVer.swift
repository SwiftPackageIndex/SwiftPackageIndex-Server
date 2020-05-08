import Vapor


struct SemVer: Content, Equatable {
    var major: Int
    var minor: Int
    var patch: Int
    var preRelease: String
    var build: String

    init(_ major: Int, _ minor: Int, _ patch: Int, _ preRelease: String = "", _ build: String = "") {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preRelease = preRelease
        self.build = build
    }
}


extension SemVer: ExpressibleByStringLiteral {
    // This initialiser is required for serialisation to the DB - i.e. it needs to have
    // access to a non-failable conversion from string to SemVer.
    // SemVer(0, 0, 0) is a safe default.
    init(stringLiteral value: StringLiteralType) {
        self = SemVer(value) ?? .init(0, 0, 0)
    }
}


extension SemVer {
    static func isValid(_ string: String) -> Bool { SemVer(string) != nil }
}


extension SemVer: LosslessStringConvertible {
    init?(_ string: String) {
        let groups = semVerRegex.matchGroups(string)
        guard
            groups.count == semVerRegex.numberOfCaptureGroups,
            let major = Int(groups[0]),
            let minor = Int(groups[1]),
            let patch = Int(groups[2])
            else { return nil }
        self = .init(major, minor, patch, groups[3], groups[4])
    }

    var description: String {
        let pre = preRelease.isEmpty ? "" : "-" + preRelease
        let bld = build.isEmpty ? "" : "+" + build
        return "\(major).\(minor).\(patch)\(pre)\(bld)"
    }
}


// Source: https://regex101.com/r/Ly7O1x/3/
// Linked from https://semver.org
let semVerRegex = NSRegularExpression(#"""
^
v?                              # SPI extension: allow leading 'v'
(?<major>0|[1-9]\d*)
\.
(?<minor>0|[1-9]\d*)
\.
(?<patch>0|[1-9]\d*)
(?:-
  (?<prerelease>
    (?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)
    (?:\.
      (?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)
    )
  *)
)?
(?:\+
  (?<buildmetadata>[0-9a-zA-Z-]+
    (?:\.[0-9a-zA-Z-]+)
  *)
)?
$
"""#, options: [.allowCommentsAndWhitespace])
