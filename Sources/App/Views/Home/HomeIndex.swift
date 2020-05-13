import Plot


class HomeIndex: SPIPage {
    override func content() -> Node<HTML.BodyContext> {
        .main(
            .p("Home page")
        )
    }

    override func nav() -> Node<HTML.BodyContext> {
        .ul(.li("Package list"),
            .li("About"))
    }
}
