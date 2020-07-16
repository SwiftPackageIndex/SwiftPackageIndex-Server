@testable import App


extension BuildIndex.Model {
    static var mock: Self {
        .init(
            packageName: "foobar",
            stable: .init(
                name: "1.2.3",
                kind: .stable,
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
                    Build(swiftVersion: .init(4, 2, 3), platform: .macos("x86_64"), status: .failed),
                    Build(swiftVersion: .init(4, 2, 3), platform: .ios(""), status: .failed),
                    Build(swiftVersion: .init(4, 2, 3), platform: .tvos(""), status: .failed),
                ]),
            latest: .init(
                name: "main",
                kind: .latest,
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
                    Build(swiftVersion: .init(4, 2, 3), platform: .macos("x86_64"), status: .failed),
                    Build(swiftVersion: .init(4, 2, 3), platform: .ios(""), status: .failed),
                    Build(swiftVersion: .init(4, 2, 3), platform: .tvos(""), status: .failed),
                ]
            ),
            beta: .init(
                name: "2.0.0-b1",
                kind: .beta,
                builds: [
                    Build(swiftVersion: .init(5, 2, 4), platform: .macos("x86_64"), status: .ok),
                    Build(swiftVersion: .init(5, 2, 4), platform: .ios(""), status: .ok),
                    Build(swiftVersion: .init(5, 2, 4), platform: .tvos(""), status: .ok),
                    Build(swiftVersion: .init(5, 1, 5), platform: .macos("x86_64"), status: .ok),
                    Build(swiftVersion: .init(5, 1, 5), platform: .ios(""), status: .ok),
                    Build(swiftVersion: .init(5, 1, 5), platform: .tvos(""), status: .ok),
                    Build(swiftVersion: .init(5, 0, 3), platform: .macos("x86_64"), status: .failed),
                    Build(swiftVersion: .init(5, 0, 3), platform: .ios(""), status: .failed),
                    Build(swiftVersion: .init(5, 0, 3), platform: .tvos(""), status: .failed),
                    Build(swiftVersion: .init(4, 2, 3), platform: .macos("x86_64"), status: .failed),
                    Build(swiftVersion: .init(4, 2, 3), platform: .ios(""), status: .failed),
                    Build(swiftVersion: .init(4, 2, 3), platform: .tvos(""), status: .failed),
                ]
            )
        )
    }
}
