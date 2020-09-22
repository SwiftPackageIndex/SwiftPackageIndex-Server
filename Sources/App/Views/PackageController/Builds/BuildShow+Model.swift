extension BuildShow {

    struct Model {
        var packageName: String
        var repositoryName: String
        var repositoryOwner: String
        var buildInfo: BuildInfo
        var versionId: Version.Id

        @available(*, deprecated)
        init?(build: App.Build) {
            guard
                let packageName = build.version.package.name(),
                let repository = build.version.package.repository,
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name,
                let buildInfo = BuildInfo(build),
                let version = build.$version.value,
                let versionId = version.id
            else { return nil }
            self.init(buildInfo: buildInfo,
                      packageName: packageName,
                      repositoryOwner: repositoryOwner,
                      repositoryName: repositoryName,
                      versionId: versionId)
        }

        init?(build: App.Build, logs: String?) {
            guard
                let packageName = build.version.package.name(),
                let repository = build.version.package.repository,
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name,
                let buildInfo = BuildInfo(build: build, logs: logs),
                let version = build.$version.value,
                let versionId = version.id
            else { return nil }
            self.init(buildInfo: buildInfo,
                      packageName: packageName,
                      repositoryOwner: repositoryOwner,
                      repositoryName: repositoryName,
                      versionId: versionId)
        }

        internal init(buildInfo: BuildInfo,
                      packageName: String,
                      repositoryOwner: String,
                      repositoryName: String,
                      versionId: Version.Id) {
            self.buildInfo = buildInfo
            self.packageName = packageName
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
            self.versionId = versionId
        }
    }

    struct BuildInfo {
        var buildCommand: String
        var logs: String
        var platform: App.Build.Platform
        var status: App.Build.Status
        var swiftVersion: SwiftVersion

        @available(*, deprecated)
        init?(_ build: App.Build) {
            guard let swiftVersion = build.swiftVersion.compatibility else { return nil }
            self.init(buildCommand: build.buildCommand ?? "build command unavailable",
                      logs: build.logs ?? "no logs recorded",
                      platform: build.platform,
                      status: build.status,
                      swiftVersion: swiftVersion)
        }

        init?(build: App.Build, logs: String?) {
            guard let swiftVersion = build.swiftVersion.compatibility else { return nil }
            self.init(buildCommand: build.buildCommand ?? "build command unavailable",
                      logs: logs ?? "no logs recorded",
                      platform: build.platform,
                      status: build.status,
                      swiftVersion: swiftVersion)
        }

        internal init(buildCommand: String,
                      logs: String,
                      platform: App.Build.Platform,
                      status: App.Build.Status,
                      swiftVersion: SwiftVersion) {
            self.buildCommand = buildCommand
            self.logs = logs
            self.platform = platform
            self.status = status
            self.swiftVersion = swiftVersion
        }

        var xcodeVersion: String? {
            switch (platform, swiftVersion) {
                case (.ios, let swift),
                     (.macosXcodebuild, let swift),
                     (.macosXcodebuildArm, let swift),
                     (.tvos, let swift),
                     (.watchos, let swift):
                    return swift.xcodeVersion
                case (.macosSpm, _), (.macosSpmArm, _), (.linux, _):
                    return nil
            }
        }

    }
}


extension BuildShow.Model {
    var buildsURL: String {
        SiteURL.package(.value(repositoryOwner), .value(repositoryName), .builds).relativeURL()
    }

    var packageURL: String {
        SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).relativeURL()
    }
}
