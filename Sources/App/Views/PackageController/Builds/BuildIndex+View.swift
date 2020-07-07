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
                .h1("Builds for \(model.packageName)"),
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

            self.packageName = name
            self.stable = .init(name: stable?.reference?.description ?? "n/a",
                                builds: stable?.builds.map(Build.init) ?? [])
            self.latest = .init(name: latest?.reference?.description ?? "n/a",
                                builds: latest?.builds.map(Build.init) ?? [])
            self.beta = .init(name: beta?.reference?.description ?? "n/a",
                              builds: beta?.builds.map(Build.init) ?? [])
        }

        struct BuildGroup {
            var name: String
            var builds: [Build]

            func node(_ label: String) -> Node<HTML.BodyContext> {
                .group(
                    .h4("\(label): \(name)"),
                    .ul(
                        .forEach(builds) {
                            .li($0.node)
                        }
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
