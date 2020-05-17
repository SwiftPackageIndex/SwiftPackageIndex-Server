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
            ),
            .ul(
                .class("metadata"),
                .li(
                    .class("authors"),
                    "By ",
                    .a(
                        .href("https://github.com/cnoon"),
                        "Christian Noon"
                    ),
                    ", ",
                    .a(
                        .href("https://github.com/mattt"),
                        "Mattt"
                    ),
                    ", ",
                    .a(
                        .href("https://github.com/jshier"),
                        "Jon Shier"
                    ),
                    ", ",
                    .a(
                        .href("https://github.com/kcharwood"),
                        "Kevin Harwood"
                    ),
                    ", and ",
                    .a(
                        .href("https://github.com/Alamofire/Alamofire/graphs/contributors"),
                        "186 other contributors"
                    ),
                    "."
                ),
                .li(
                    .class("history"),
                    "In development for over 5 years, with ",
                    .a(
                        .href("https://github.com/Alamofire/Alamofire/commits/master"),
                        "1,433 commits"
                    ),
                    " and ",
                    .a(
                        .href("https://github.com/Alamofire/Alamofire/releases"),
                        "79 releases"
                    ),
                    "."
                ),
                .li(
                    .class("activity"),
                    "There are ",
                    .a(
                        .href("https://github.com/Alamofire/Alamofire/issues"),
                        "27 open issues"
                    ),
                    ", and ",
                    .a(
                        .href("https://github.com/Alamofire/Alamofire/pulls"),
                        "5 open pull requests"
                    ),
                    ". The last pull request was closed/merged 6 days ago."
                ),
                .li(
                    .class("products"),
                    "Alamofire contains ",
                    .strong(
                        "3 libraries"
                    ),
                    " and ",
                    .strong(
                        "1 executable"
                    ),
                    "."
                )
            ),
            .element(named: "hr", nodes:[ // TODO: Fix after Plot update
                .attribute(named: "class", value: "short")
            ])
        )
    }

}
