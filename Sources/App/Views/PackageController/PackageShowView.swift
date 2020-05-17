import Foundation
import Plot


class PackageShowView: PublicPage {

    let model: Model

    init(_ model: Model) {
        self.model = model
    }

    override func pageTitle() -> String? {
        model.title
    }

    override func content() -> Node<HTML.BodyContext> {
        .group(
            .div(
                .class("split"),
                .div(
                    .h2(.text(model.title)),
                    .element(named: "small", nodes: [ // TODO: Fix after Plot update
                        .a(
                            .href(model.url),
                            .text(model.url.absoluteString)
                        )
                    ])
                ),
                .div(
                    .class("license"),
                    .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                    .text(model.license.shortName)
                )
            ),
            .hr(),
            .p(
                .class("description"),
                .text(model.summary)
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
            ]),
            .ul(
                .class("releases"),
                .li(
                    .class("stable"),
                    "The ",
                    .strong("latest stable"),
                    " release is ",
                    .a(
                        .href("https://github.com/Alamofire/Alamofire/releases/tag/5.2.0"),
                        "5.2.0"
                    ),
                    ", 12 hours ago."
                ),
                .li(
                    .class("beta"),
                    "The ",
                    .strong("latest beta"),
                    " release is ",
                    .a(
                        .href("https://github.com/Alamofire/Alamofire/releases/tag/5.3.0-beta.1"),
                        "5.3.0-beta.1"
                    ),
                    ", 4 days ago."
                ),
                .li(
                    .class("branch"),
                    "The last commit to the ",
                    .strong("master branch"),
                    " was 12 minutes ago."
                )
            ),
            .h3("Language and Platforms"),
            .ul(
                .li(
                    .class("language"),
                    "Supports ",
                    .strong("Swift 5 and 5.2"),
                    " (changing to ",
                    .strong("Swift 5.2"),
                    " in ",
                    .a(
                        .class("beta"),
                        .href("https://github.com/Alamofire/Alamofire/releases/tag/5.3.0-beta.1"),
                        "5.3.0-beta.1"
                    ),
                    ")."
                ),
                .li(
                    .class("platforms"),
                    "Supports ",
                    .strong("iOS 10.0+"),
                    ", ",
                    .strong("macOS 10.12+"),
                    ", ",
                    .strong("watchOS 3.0+"),
                    ", and ",
                    .strong("tvOS 10.0+"),
                    " (changing to ",
                    .strong("iOS 13.0+"),
                    ", ",
                    .strong("macOS 10.15+"),
                    ", ",
                    .strong("watchOS 6.0+"),
                    ", and ",
                    .strong("tvOS 13.0+"),
                    " in ",
                    .a(
                        .class("beta"),
                        .href("https://github.com/Alamofire/Alamofire/releases/tag/5.3.0-beta.1"),
                        "5.3.0-beta.1"
                    ),
                    ")."
                )

            )
        )
    }

}


extension PackageShowView {
    struct Model {
        let title: String
        let url: URL
        let license: License
        let summary: String
//        let authors: [Author]

        struct Author {
            let name: String
            let url: URL
        }
    }
}




// FIXME: temporary compile fix
func packateToModel(_ package: Package) -> PackageShowView.Model {
    .init(title: "Alamofire",
          url: URL(string: "https://github.com/Alamofire/Alamofire.git")!,
          license: .mit,
          summary: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque quis porttitor erat. Vivamus porttitor mi odio, quis imperdiet velit blandit id. Vivamus vehicula urna eget ipsum laoreet, sed porttitor sapien malesuada. Mauris faucibus tellus at augue vehicula, vitae aliquet felis ullamcorper. Praesent vitae leo rhoncus, egestas elit id, porttitor lacus. Cras ac bibendum mauris. Praesent luctus quis nulla sit amet tempus. Ut pharetra non augue sed pellentesque."

    )
}
