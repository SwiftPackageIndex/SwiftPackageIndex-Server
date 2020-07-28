import Plot


extension BuildIndex {
    struct Model {
        var owner: String
        var repositoryName: String
        var packageName: String
        var buildCount: Int
        var buildMatrix: BuildMatrix

        init?(package: Package) {
            // we consider certain attributes as essential and return nil (raising .notFound)
            guard let name = package.name(),
                  let owner = package.repository?.owner,
                  let repositoryName = package.repository?.name else { return nil }

            let (stable, beta, latest) = package.releases()
            let buildGroups = [
                stable.flatMap { BuildGroup(version: $0, kind: .stable) },
                beta.flatMap { BuildGroup(version: $0, kind: .beta) },
                latest.flatMap { BuildGroup(version: $0, kind: .latest) }
            ].compactMap { $0 }

            self.init(owner: owner,
                      repositoryName: repositoryName,
                      packageName: name,
                      buildGroups: buildGroups)
        }

        internal init(owner: String,
                      repositoryName: String,
                      packageName: String,
                      buildGroups: [BuildGroup]) {
            self.owner = owner
            self.repositoryName = repositoryName
            self.packageName = packageName
            self.buildCount = buildGroups.reduce(0) { $0 + $1.builds.count }
            buildMatrix = .init(buildGroups: buildGroups)
        }
    }
}


extension BuildIndex.Model {
    struct BuildGroup {
        var name: String
        var kind: Kind
        var builds: [BuildInfo]

        init?(version: Version, kind: Kind) {
            guard let name = version.reference?.description else { return nil }
            self.init(name: name, kind: kind, builds: version.builds.compactMap(BuildInfo.init))
        }

        internal init(name: String, kind: Kind, builds: [BuildInfo]) {
            self.name = name
            self.kind = kind
            self.builds = builds
        }
    }

    enum Kind {
        case stable
        case beta
        case latest
    }
}


extension BuildIndex.Model {
    struct BuildInfo {
        var id: App.Build.Id
        var platform: App.Build.Platform
        var status: App.Build.Status
        var swiftVersion: App.SwiftVersion

        init?(_ build: App.Build) {
            guard let id = build.id else { return nil }
            self.id = id
            platform = build.platform
            status = build.status
            swiftVersion = build.swiftVersion
        }

        internal init(id: App.Build.Id,
                      swiftVersion: App.SwiftVersion,
                      platform: App.Build.Platform,
                      status: App.Build.Status) {
            self.id = id
            self.platform = platform
            self.status = status
            self.swiftVersion = swiftVersion
        }
    }
}


extension BuildIndex.Model {
    var packageURL: String {
        SiteURL.package(.value(owner), .value(repositoryName), .none).relativeURL()
    }

    struct BuildMatrix {
        var columnLabels: [String]
        var values: [RowIndex: [App.Build.Status?]]

        init(buildGroups: [BuildGroup]) {
            columnLabels = buildGroups.map(\.name)
            values = Dictionary.init(uniqueKeysWithValues: RowIndex.all.map { ($0, []) })

            for group in buildGroups {
                var column = [RowIndex: App.Build.Status?]()
                for build in group.builds {
                    guard let index = RowIndex(build) else { continue }
                    column[index] = build.status
                }
                RowIndex.all.forEach {
                    values[$0, default: []].append(column[$0, default: nil])
                }
            }
        }

        struct RowIndex: Hashable {
            var swiftVersion: SwiftVersionCompatibility
            var platform: Build.Platform

            init?(_ build: BuildInfo) {
                guard let swiftVersion = build.swiftVersion.compatibility else { return nil }
                self.init(swiftVersion: swiftVersion, platform: build.platform)
            }

            internal init(swiftVersion: SwiftVersionCompatibility, platform: Build.Platform) {
                self.swiftVersion = swiftVersion
                self.platform = platform
            }

            var label: String { "\(swiftVersion.longDisplayName) on \(platform.name)" }

            static var all: [RowIndex] {
                let sw: [SwiftVersionCompatibility] = [.v5_3, .v5_2, .v5_1, .v5_0, .v4_2]
                let rows: [(SwiftVersionCompatibility, Build.Platform)] = sw.reduce([]) { rows, version in
                    rows + Build.Platform.allCases.map { (version, $0) }
                }
                return rows.map(RowIndex.init(swiftVersion:platform:))
            }

            // sort descriptor to sort indexes by swift version desc, platform name asc
            static let versionPlatform: (RowIndex, RowIndex) -> Bool = { lhs, rhs in
                if lhs.swiftVersion != rhs.swiftVersion { return lhs.swiftVersion > rhs.swiftVersion }
                return lhs.platform.rawValue < rhs.platform.rawValue
            }
        }

    }
}


typealias SwiftVersionCompatibility = PackageShow.Model.SwiftVersionCompatibility


private extension SwiftVersion {
    var compatibility: SwiftVersionCompatibility? {
       for version in SwiftVersionCompatibility.all {
            if self.isCompatible(with: version) { return version }
        }
        return nil
    }

    func isCompatible(with other: SwiftVersionCompatibility) -> Bool {
        major == other.semVer.major && minor == other.semVer.minor
    }
}

