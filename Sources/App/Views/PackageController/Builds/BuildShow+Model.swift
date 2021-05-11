extension BuildShow {

    struct Model {
        var packageName: String
        var repositoryName: String
        var repositoryOwner: String
        var buildInfo: BuildInfo
        var versionId: Version.Id

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

        init?(build: App.Build, logs: String?) {
            guard let swiftVersion = build.swiftVersion.compatibility else { return nil }
            self.init(buildCommand: build.buildCommand ?? "Build command unavailable",
                      logs: logs ?? build.status.logsUnavailableDescription,
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


private extension Build.Status {
    var logsUnavailableDescription: String {
        switch self {
            case .ok:
                return "This build succeeded, but detailed logs are not available. Logs are only retained for a few months after a build, and they may have expired, or the request to fetch them may have failed."
            case .failed:
                return "This build failed, but detailed logs are not available. Logs are only retained for a few months after a build, and they may have expired, or the request to fetch them may have failed."
            case .pending:
                return "This build is pending execution, and logs are not yet available."
            case .timeout:
                return "This build exceeded its build quota and timed out."
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
