
struct SwiftVersionCompatibility: Equatable, Hashable, Comparable, BuildResultParameter {

    static func < (lhs: SwiftVersionCompatibility, rhs: SwiftVersionCompatibility) -> Bool {
        lhs.displayName < rhs.displayName
    }

    var displayName: String
    var semVer: SemVer
    var isLatest: Bool
    var isBeta: Bool

    var longDisplayName: String { "Swift \(displayName)" }

    var note: String? {
        if isLatest { return "latest" }
        if isBeta { return "beta" }
        return nil
    }

    static let v4_2: Self = .init(displayName: "4.2",
                                  semVer: .init(4, 2, 0),
                                  isLatest: false,
                                  isBeta: false)
    static let v5_0: Self = .init(displayName: "5.0",
                                  semVer: .init(5, 0, 0),
                                  isLatest: false,
                                  isBeta: false)
    static let v5_1: Self = .init(displayName: "5.1",
                                  semVer: .init(5, 1, 0),
                                  isLatest: false,
                                  isBeta: false)
    static let v5_2: Self = .init(displayName: "5.2",
                                  semVer: .init(5, 2, 0),
                                  isLatest: true,
                                  isBeta: false)
    static let v5_3: Self = .init(displayName: "5.3",
                                  semVer: .init(5, 3, 0),
                                  isLatest: false,
                                  isBeta: true)

    static var all: [Self] { [v4_2, v5_0, v5_1, v5_2, v5_3] }

    var xcodeVersion: String? {
        // Match with https://gitlab.com/finestructure/swiftpackageindex-builder/-/blob/main/Sources/BuilderCore/ArgumentTypes.swift#L36
        switch self {
            case .v4_2:
                return "Xcode 10.1"
            case .v5_0:
                return "Xcode 10.3"
            case .v5_1:
                return "Xcode 11.3.1"
            case .v5_2:
                return "Xcode 11.6"
            case .v5_3:
                return "Xcode 12 beta"
            default:
                return nil
        }
    }
}


extension SwiftVersionCompatibility {
    func isCompatible(with other: SwiftVersion) -> Bool {
        semVer.major == other.major && semVer.minor == other.minor
    }
}


extension SwiftVersion {
    func isCompatible(with other: SwiftVersionCompatibility) -> Bool {
        other.isCompatible(with: self)
    }

    var compatibility: SwiftVersionCompatibility? {
       for version in SwiftVersionCompatibility.all {
            if self.isCompatible(with: version) { return version }
        }
        return nil
    }
}
