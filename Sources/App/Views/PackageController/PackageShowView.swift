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
                            .text(model.url)
                        )
                    ])
                ),
                .div(
                    .class("license"),
                    .attribute(named: "title", value: model.license.fullName), // TODO: Fix after Plot update
                    .i(.class("icon osi")),
                    .text(model.license.shortName)
                )
            ),
            .hr(),
            .p(
                .class("description"),
                .text(model.summary)
            ),
            .section(
                .class("metadata"),
                .ul(
                    .li(
                        .class("icon author"),
                        .group(model.authorsClause())
                    )
                    ,
                    .li(
                        .class("icon history"),
                        .group(model.historyClause())
                    ),
                    .li(
                        .class("icon activity"),
                        .group(model.activityClause())
                    ),
                    .li(
                        .class("icon products"),
                        .group(model.productsClause())
                    )
                )
            ),
            .element(named: "hr", nodes:[ // TODO: Fix after Plot update
                .attribute(named: "class", value: "short")
            ]),
            .section(
                .class("releases"),
                .ul(
                    .li(
                        .class("icon stable"),
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
                        .class("icon beta"),
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
                        .class("icon branch"),
                        "The last commit to the ",
                        .strong("master branch"),
                        " was 12 minutes ago."
                    )
                )
            ),
            .section(
                .class("language_platforms"),
                .h3("Language and Platforms"),
                .ul(
                    .li(
                        .class("icon language"),
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
                        .class("icon platforms"),
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
        )
    }

}


extension PackageShowView {
    struct Model {
        let title: String
        let url: String
        let license: License
        let summary: String
        let authors: [Link]
        let history: History
        let activity: Activity
        let products: (libraries: Int, executables: Int)?

        struct Link {
            let name: String
            let url: String
        }

        struct History {
            let since: String  // TODO: use Date and derive on the fly
            let commits: Link
            let releases: Link
        }

        struct Activity {
            let openIssues: Link
            let pullRequests: Link
            let lastPullRequestClosedMerged: String
        }
    }
}


extension PackageShowView.Model {
    func authorsClause() -> [Node<HTML.BodyContext>] {
        switch authors.count {
            case 0:
                return ["–"]
            case 1:
                let author = authors.first!
                return ["By ", .a(.href(author.url), .text(author.name)), "."]
            case 2:
                let author1 = authors[0]
                let author2 = authors[1]
                return ["By ", .a(.href(author1.url), .text(author1.name)),
                        " and ", .a(.href(author2.url), .text(author2.name)), "."]
            default:
                let start: [Node<HTML.BodyContext>]
                    = ["By ", .a(.href(authors.first!.url), .text(authors.first!.name))]
                let middle: [[Node<HTML.BodyContext>]] = authors[1..<(authors.count - 1)].map {
                        [", ", .a(.href($0.url), .text($0.name))]
                }
                let end: [Node<HTML.BodyContext>] =
                    [", and ", .a(.href(authors.last!.url), .text(authors.last!.name)), "."]
                return middle.reduce(start) { $0 + $1 } + end
        }
    }

    func historyClause() -> [Node<HTML.BodyContext>] {
        [
            "In development for \(history.since), with ",
            .a(
                .href(history.commits.url),
                .text(history.commits.name)
            ),
            " and ",
            .a(
                .href(history.releases.url),
                .text(history.releases.name)
            ),
            "."
        ]
    }

    func activityClause() -> [Node<HTML.BodyContext>] {
        [
            "There are ",
            .a(
                .href(activity.openIssues.url),
                .text(activity.openIssues.name)
            ),
            ", and ",
            .a(
                .href(activity.pullRequests.url),
                .text(activity.pullRequests.name)
            ),
            ". The last pull request was closed/merged \(activity.lastPullRequestClosedMerged)."
        ]
    }

    func productsClause() -> [Node<HTML.BodyContext>] {
        guard let products = products else { return [] }
        return [
            "\(title) contains ",
            .strong(
                .text(pluralize(count: products.libraries, singular: "library", plural: "libraries"))
            ),
            " and ",
            .strong(
                .text(pluralize(count: products.executables, singular: "executable"))
            ),
            "."
        ]
    }
}
