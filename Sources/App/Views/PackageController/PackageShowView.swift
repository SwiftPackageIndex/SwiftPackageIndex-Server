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
        .p(
            .text(String(describing: package.id!))
        )
    }

}
