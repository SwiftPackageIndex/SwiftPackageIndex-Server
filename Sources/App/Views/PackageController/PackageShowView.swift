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
            .hr(),
            .p(
                .class("description"),
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque quis porttitor erat. Vivamus porttitor mi odio, quis imperdiet velit blandit id. Vivamus vehicula urna eget ipsum laoreet, sed porttitor sapien malesuada. Mauris faucibus tellus at augue vehicula, vitae aliquet felis ullamcorper. Praesent vitae leo rhoncus, egestas elit id, porttitor lacus. Cras ac bibendum mauris. Praesent luctus quis nulla sit amet tempus. Ut pharetra non augue sed pellentesque."
            )
        )
    }

}
