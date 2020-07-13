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
                                builds: stable?.builds
                                    .map(Build.init)
                                    .sorted(by: versionPlatform) ?? [])
            self.latest = .init(name: latest?.reference?.description ?? "n/a",
                                builds: latest?.builds
                                    .map(Build.init)
                                    .sorted(by: versionPlatform) ?? [])
            self.beta = .init(name: beta?.reference?.description ?? "n/a",
                              builds: beta?.builds
                                .map(Build.init)
                                .sorted(by: versionPlatform) ?? [])
        }

        struct BuildGroup {
            var name: String
            var builds: [Build]

            func node(_ label: String) -> Node<HTML.BodyContext> {
//                .group(
//                    .h4("\(label): \(name)"),
//                    .ul(
//                        .forEach(builds) {
//                            .li($0.node)
//                        }
//                    )
//                )

                .group(
                    .h3(
                        .span(
                            .class("stable"),
                            .i(.class("icon stable")),  // Or "icon branch" or "icon beta"
                            .text("1.0.0")
                        )
                    ),
                    .section(
                        .class("builds"),
                        .ul(
                            .forEach(1..<10) { _ in
                                .li(
                                    .div(
                                        .class("status failed"), // Or "status failed"
                                        .i(.class("icon build_failed")) // Or "icon build_failed"
                                    ),
                                    .strong("Swift 4.2"),
                                    .text(" on "),
                                    .strong("macOS"),
                                    .text(" &ndash; "),
                                    .a( // Should we show logs for all builds or only failed?
                                        .href("#"), // Path to log page for this build
                                        "View build log"
                                    )
                                )
                            }
//                        .forEach(builds) { build in
//                            .li(build.node)
//                        }
                        )
                    )
                )
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

            var node: Node<HTML.BodyContext> {
                .group(
                    .text("\(swiftVersion)"), " – ",
                    .text("\(platform.name)"), " – ",
                    .text("\(status)")
                )
            }
        }
    }
}
