import Vapor


extension Package {

    /// Returns a list of compatible swift versions across a package's significant versions.
    /// - Returns: Array of compatible `SwiftVersion`s
    func swiftVersionCompatibility() -> [SwiftVersion] {
        let versions = [Version.Kind.release, .preRelease, .defaultBranch]
            .compactMap(latestVersion(for:))
        let builds: [Build] = versions.reduce(into: []) {
            $0.append(contentsOf: $1.$builds.value ?? [])
        }
        let compatibility = SwiftVersion.allActive.map { swiftVersion -> (SwiftVersion, Bool) in
            for build in builds {
                if build.swiftVersion.isCompatible(with: swiftVersion) {
                    return (swiftVersion, true)
                }
            }
            return (swiftVersion, false)
        }
        return compatibility
            .filter { $0.1 }
            .map { $0.0 }
    }

}
