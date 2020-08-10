
extension Build {
    enum Platform: String, Codable, Equatable {
        case ios
        case macosSpmArm        = "macos-spm-arm"
        case macosXcodebuildArm = "macos-xcodebuild-arm"
        case macosSpm           = "macos-spm"
        case macosXcodebuild    = "macos-xcodebuild"
        case tvos
        case watchos
        case linux

        var name: String {
            switch self {
                case .ios:
                    return "iOS"
                case .macosSpmArm:
                    return "macOS - SPM - ARM"
                case .macosXcodebuildArm:
                    return "macOS - xcodebuild - ARM"
                case .macosSpm:
                    return "macOS - SPM"
                case .macosXcodebuild:
                    return "macOS - xcodebuild"
                case .tvos:
                    return "tvOS"
                case .watchos:
                    return "watchOS"
                case .linux:
                    return "Linux"
            }
        }

        var displayName: String {
            switch self {
                case .ios:
                    return "iOS"
                case .macosSpmArm:
                    return "macOS (SPM, ARM)"
                case .macosXcodebuildArm:
                    return "macOS (Xcode, ARM)"
                case .macosSpm:
                    return "macOS (SPM)"
                case .macosXcodebuild:
                    return "macOS (Xcode)"
                case .tvos:
                    return "tvOS"
                case .watchos:
                    return "watchOS"
                case .linux:
                    return "Linux"
            }
        }

        /// Currently supported build platforms
        static var allActive: [Self] {
            [.ios, .macosSpm, .macosXcodebuild, .macosSpmArm, .macosXcodebuildArm, .linux, .tvos, .watchos]
        }
    }
}


extension Build.Platform: Comparable {
    static func < (lhs: Build.Platform, rhs: Build.Platform) -> Bool {
        switch (allActive.firstIndex(of: lhs), allActive.firstIndex(of: rhs)) {
            case let (.some(idx1), .some(idx2)):
                return idx1 < idx2
            default:
                return lhs.rawValue < rhs.rawValue
        }
    }
}
