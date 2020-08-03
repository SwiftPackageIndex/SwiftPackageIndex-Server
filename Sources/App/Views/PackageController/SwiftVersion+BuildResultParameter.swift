
extension SwiftVersion: BuildResultParameter {
    var displayName: String { "\(major).\(minor)" }
    var longDisplayName: String { "Swift \(displayName)" }

    var note: String? {
        if isLatest { return "latest" }
        if isBeta { return "beta" }
        return nil
    }

    var isLatest: Bool { isCompatible(with: .v5_2) }
    var isBeta: Bool { isCompatible(with: .v5_3) }
}
