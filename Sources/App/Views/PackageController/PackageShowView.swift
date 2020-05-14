import Plot


class PackageShowView: PublicPage {

    let package: Package

    init(_ package: Package) {
        self.package = package
    }

    override func pageTitle() -> String? {
        "Alamofire"
    }

    override func content() -> Node<HTML.BodyContext> {
        .group(
            .div(
                .class("split"),
                .div(
                    .h2("Alamofire"),
                    .element(named: "small", nodes: [ // TODO: Fix after Plot update
                        .a(
                            .href("https://github.com/Alamofire/Alamofire.git"),
                            "https://github.com/Alamofire/Alamofire.git"
                        )
                    ])
                ),
                .div(
                    .class("license"),
                    .attribute(named: "title", value: "MIT License"), // TODO: Fix after Plot update
                    "MIT"
                )
            ),
            .hr()
        )
    }

}
