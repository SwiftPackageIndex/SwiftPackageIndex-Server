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
                .h2("Alamofire"),
                .div(
                    .class("license"),
                    .attribute(named: "title", value: "MIT License"), // TODO: Suggest that Plot is able to add `title` attributes on div elements (and on any other element!)
                    "MIT"
                )
            )
        )
    }

}
