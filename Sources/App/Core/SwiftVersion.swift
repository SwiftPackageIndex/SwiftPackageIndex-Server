// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor


struct SwiftVersion: Content, Equatable, Hashable {
    var major: Int
    var minor: Int
    var patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}


extension SwiftVersion: LosslessStringConvertible {
    init?(_ string: String) {
        let groups = Self.swiftVerRegex.matchGroups(string)
        guard
            groups.count == Self.swiftVerRegex.numberOfCaptureGroups,
            let major = Int(groups[0])
        else { return nil }
        self = .init(major, Int(groups[1]) ?? 0, Int(groups[2]) ?? 0)
    }

    enum ZeroStrategy {
        case none
        case all
        case patch
    }

    var description: String { description(droppingZeroes: .none) }

    func description(droppingZeroes zeroStrategy: ZeroStrategy) -> String {
        switch zeroStrategy {
            case .none:
                return "\(major).\(minor).\(patch)"

            case .all:
                switch (major, minor, patch) {
                    case let (major, 0, 0):
                        return "\(major)"
                    case let (major, minor, 0):
                        return "\(major).\(minor)"
                    default:
                        return "\(major).\(minor).\(patch)"
                }

            case .patch:
                switch (major, minor, patch) {
                    case let (major, minor, 0):
                        return "\(major).\(minor)"
                    default:
                        return "\(major).\(minor).\(patch)"
                }

        }
    }

    static var swiftVerRegex: NSRegularExpression {
        NSRegularExpression(
            #"""
            ^
            v?                              # SPI extension: allow leading 'v'
            (?<major>0|[1-9]\d*)
            (?:\.
              (?<minor>0|[1-9]\d*)
            )?
            (?:\.
              (?<patch>0|[1-9]\d*)
            )?
            $
            """#, options: [.allowCommentsAndWhitespace]
        )
    }

}


extension SwiftVersion: Comparable {
    static func < (lhs: SwiftVersion, rhs: SwiftVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}


extension DefaultStringInterpolation {
    mutating func appendInterpolation(_ swiftVersion: SwiftVersion, droppingZeroes zeroStrategy: SwiftVersion.ZeroStrategy = .none) {
        appendInterpolation(swiftVersion.description(droppingZeroes: zeroStrategy))
    }
}


extension SwiftVersion {
    func isCompatible(with other: SwiftVersion) -> Bool {
        major == other.major && minor == other.minor
    }
}


extension SwiftVersion {
    static var latest: Self { allActive.sorted().last! }
}
