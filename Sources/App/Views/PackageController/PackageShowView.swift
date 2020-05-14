import Plot


class PackageShowView: PublicPage {

    let package: Package

    init(_ package: Package) {
        self.package = package
    }

    override func content() -> Node<HTML.BodyContext> {
        .main(.text(String(describing: package.id!)))
    }
    
}
