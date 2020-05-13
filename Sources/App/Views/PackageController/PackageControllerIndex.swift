import Plot


extension SPIPage {
    static func packageIndex(_ packages: [Package]) -> HTML {
        SPIPage.document(
            .main(
                .group(
                    packages.map(\.url).map { .pre(.text($0)) }
                )
            )
        )
    }
}
