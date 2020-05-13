import Plot


class PackagesIndex: SPIPage {
    let packages: [Package]

    init(packages: [Package]) {
        self.packages = packages
    }

    override func content() -> Node<HTML.BodyContext> {
        .main(
            .group(
                packages.map(\.url).map { .pre(.text($0)) }
            )
        )
    }
}
