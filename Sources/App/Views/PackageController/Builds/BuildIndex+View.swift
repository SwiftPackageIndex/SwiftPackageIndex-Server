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


#if DEBUG
extension BuildIndex {
    struct Model {
        var packageName: String
        var stable: BuildGroup
        var latest: BuildGroup
        var beta: BuildGroup

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

            var node: Node<HTML.BodyContext> {
                .group(
                    .text("\(swiftVersion)"), " – ",
                    .text("\(platform.name)"), " – ",
                    .text("\(status)")
                )
            }
        }

        static var mock: Self {
            .init(
                packageName: "foobar",
                stable: .init(
                    name: "1.2.3",
                    builds: [
                        Build(swiftVersion: .init(5, 2, 4), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(5, 2, 4), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 2, 4), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(5, 1, 5), platform: .macos("x86_64"), status: .ok),
                                Build(swiftVersion: .init(5, 1, 5), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 1, 5), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .tvos(""), status: .ok),
                    ]
                ),
                latest: .init(
                    name: "main",
                    builds: [
                        Build(swiftVersion: .init(5, 2, 4), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(5, 2, 4), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 2, 4), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(5, 1, 5), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(5, 1, 5), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 1, 5), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .tvos(""), status: .ok),
                    ]
                ),
                beta: .init(
                    name: "2.0.0-b1",
                    builds: [
                        Build(swiftVersion: .init(5, 2, 4), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(5, 2, 4), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 2, 4), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(5, 1, 5), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(5, 1, 5), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 1, 5), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(5, 0, 3), platform: .tvos(""), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .macos("x86_64"), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .ios(""), status: .ok),
                        Build(swiftVersion: .init(4, 2, 3), platform: .tvos(""), status: .ok),
                    ]
                )
            )
        }
    }
}
#endif
