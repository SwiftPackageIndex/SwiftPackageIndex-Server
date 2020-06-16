import Plot


extension PublicPage {

    static func admin() -> HTML {
        let title = "Swift Package Index"

        return HTML(
            adminHead(title: title),
            .body(
                .container(
                    .row(.h2(.text(title))),
                    reconcileButton(),
                    ingestButton()
                )
            )
        )
    }

    static func adminHead(title: String) -> Node<HTML.DocumentContext> {
        .head(
            .meta(.charset(.utf8)),
            .meta(.name("viewport"), .content("width=device-width, initial-scale=1, shrink-to-fit=no")),
            .link(
                .rel(.stylesheet),
                .href("https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"),
                .integrity("sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO"),
                .init(name: "crossorigin", value: "anonymous")
            ),
            .link(
                .href("/stylesheets/grid.css"),
                .rel(.stylesheet)
            ),
            .title(title)
        )
    }

}

func reconcileButton() -> Node<HTML.BodyContext> {
    .form(
        .action("/api/packages/run/reconcile"),
        .method(.get),
        .row(
            .input(.class("btn btn-primary"), .type(.submit), .value("Reconcile"))
        ),
        .row(
            .label(.text("Reconcile the package list with the Package Index."))
        )
    )
}


func ingestButton() -> Node<HTML.BodyContext> {
    .form(
        .action("/api/packages/run/ingest"),
        .method(.get),
        .row(
            .input(.class("btn btn-primary"), .type(.submit), .value("Ingest"))
        ),
        .row(
            .label(.text("Ingest metadata for a batch of packages."))
        )
    )
}
