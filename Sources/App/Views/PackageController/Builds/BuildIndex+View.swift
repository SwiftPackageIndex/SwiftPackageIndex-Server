import Plot


enum BuildIndex {

    class View: PublicPage {

        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func content() -> Node<HTML.BodyContext> {
            .div(
                .h2("Builds for \(model.packageName)"),
                model.stable.node("Stable"),
                model.latest.node("Latest"),
                model.beta.node("Beta")
            )
        }
    }

}


extension BuildIndex {
    struct Model {
        var packageName: String
        var stable: BuildGroup
        var latest: BuildGroup
        var beta: BuildGroup

        init?(package: Package) {
            // we consider certain attributes as essential and return nil (raising .notFound)
            guard let name = package.name() else { return nil }
            let (stable, beta, latest) = package.releases()

            // sort builds by swift version desc, platform name
            let versionPlatform: (Build, Build) -> Bool = { lhs, rhs in
                if lhs.swiftVersion != rhs.swiftVersion { return lhs.swiftVersion > rhs.swiftVersion }
                return lhs.platform.name.rawValue < rhs.platform.name.rawValue
            }

            self.packageName = name
            self.stable = .init(name: stable?.reference?.description ?? "n/a",
                                kind: .stable,
                                builds: stable?.builds
                                    .map(Build.init)
                                    .sorted(by: versionPlatform) ?? [])
            self.latest = .init(name: latest?.reference?.description ?? "n/a",
                                kind: .latest,
                                builds: latest?.builds
                                    .map(Build.init)
                                    .sorted(by: versionPlatform) ?? [])
            self.beta = .init(name: beta?.reference?.description ?? "n/a",
                              kind: .beta,
                              builds: beta?.builds
                                .map(Build.init)
                                .sorted(by: versionPlatform) ?? [])
        }

        internal init(packageName: String,
                      stable: BuildGroup,
                      latest: BuildGroup,
                      beta: BuildGroup) {
            self.packageName = packageName
            self.stable = stable
            self.latest = latest
            self.beta = beta
        }

        struct BuildGroup {
            var name: String
            var kind: Kind
            var builds: [Build]

            func node(_ label: String) -> Node<HTML.BodyContext> {
                .group(
                    .h3(
                        .span(
                            .class(cssClass),
                            .i(.class("icon \(cssClass)")),
                            .text(name)
                        )
                    ),
                    .section(
                        .class("builds"),
                        .ul(
                            .forEach(builds) { $0.node }
                        )
                    )
                )
            }

            enum Kind {
                case stable
                case beta
                case latest
            }

            var cssClass: String {
                switch kind {
                    case .stable:
                        return "stable"
                    case .beta:
                        return "beta"
                    case .latest:
                        return "branch"
                }
            }
        }

        struct Build {
            var swiftVersion: App.SwiftVersion
            var platform: App.Build.Platform
            var status: App.Build.Status

            init(_ build: App.Build) {
                swiftVersion = build.swiftVersion
                platform = build.platform
                status = build.status
            }

            internal init(swiftVersion: App.SwiftVersion,
                          platform: App.Build.Platform,
                          status: App.Build.Status) {
                self.swiftVersion = swiftVersion
                self.platform = platform
                self.status = status
            }

            var node: Node<HTML.ListContext> {
                .li(
                    .div(
                        .class("status \(cssClass)"),
                        .i(.class("icon build_\(cssClass)"))
                    ),
                    .strong(.text(swiftVersionLabel)),
                    .text(" on "),
                    .strong("\(platform.name)"),
                    .text(" &ndash; "),
                    .a(
                        .href("#"), // Path to log page for this build
                        "View build log"
                    )
                )
            }

            var cssClass: String {
                switch status {
                    case .ok:
                        return "success"
                    case .failed:
                        return "failed"
                }
            }

            var swiftVersionLabel: String {
                "Swift \(swiftVersion.major)/\(swiftVersion.minor)"
            }
        }
    }
}
