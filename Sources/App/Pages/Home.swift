import Plot


func homePage() -> HTML {
    let title = "Swift Package Index"

    return HTML(
        myhead(title: title),
        .body(
            .container(
                .row(.h2(.text(title))),
                reconcileButton(),
                ingestButton()
            )
        )
    )
}


func reconcileButton() -> Node<HTML.BodyContext> {
    .form(
        .action("/packages/run/reconcile"),
        .method(.get),
        .row(
            .input(.class("btn btn-primary"), .type(.submit), .value("Reconcile"))
        ),
        .row(
            .label(.text("Reconcile the master package list with the Package Index."))
        )
    )
}


func ingestButton() -> Node<HTML.BodyContext> {
    .form(
        .action("/packages/run/ingest"),
        .method(.get),
        .row(
            .input(.class("btn btn-primary"), .type(.submit), .value("Ingest"))
        ),
        .row(
            .label(.text("Ingest metadata for a batch of packages."))
        )
    )
}
