import Plot

class PackageControllerIndex: PublicPage {

    override func content() -> Node<HTML.BodyContext> {
        .main(.p("Hello, World."))
    }

}
